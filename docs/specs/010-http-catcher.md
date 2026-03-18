# Spec 010 — HTTP Catcher: Webhooks, Forms & Heartbeats

> Extend Inboxed's "catch, inspect, assert" model to HTTP requests. A public endpoint receives any HTTP request and stores it for inspection via Dashboard, REST API, and MCP. Three endpoint types — webhook, form, heartbeat — share one infrastructure with type-specific UX.

**Phase:** 8
**Status:** implemented
**Created:** 2026-03-16
**Depends on:** [001 — Architecture](001-architecture.md) (layer rules), [008 — Webhooks](008-webhooks.md) (outbound delivery infra for heartbeat alerts), [009 — Usability](009-usability.md) (layout primitives, module sidebar, route slots, feature flags)
**ADRs:** [021 — HTTP Catcher](../adrs/021-webhook-catcher.md), [023 — Endpoint Type Polymorphism](../adrs/023-endpoint-type-polymorphism.md), [024 — Heartbeat State Machine](../adrs/024-heartbeat-state-machine.md), [025 — Public Catch Endpoint Security](../adrs/025-public-catch-endpoint-security.md)
**Expert panel:** API Design Architect, Full-Stack Engineer, Security Engineer, MCP Engineer, UX/UI Designer

---

## 1. Objective

Build the HTTP catcher — Inboxed's second primitive. Developers point external services (Stripe, GitHub, cron jobs, HTML forms) at a unique Inboxed URL. Every HTTP request is captured, stored, and made inspectable via the same channels as email: Dashboard, REST API, MCP.

Three endpoint types share one table and one public catch URL:

| Type | Use case | What makes it special |
|---|---|---|
| **Webhook** | Catch Stripe/GitHub/Twilio callbacks | JSON pretty-print, header inspection |
| **Form** | Catch HTML form submissions during prototyping | Field table UI, file uploads, configurable response (redirect/HTML) |
| **Heartbeat** | Monitor cron jobs and background tasks | Expected interval, status badges, alerting on missed pings |

**Guiding principle:** The HTTP catcher is the same "catch, inspect, assert" pattern as email. Same project, same API keys, same TTL, same MCP. The only difference is the protocol.

---

## 2. Current State

### What exists

- **Projects + API keys** — multi-project support with token authentication
- **Webhook delivery** (Phase 7, spec 008) — outbound HTTP notifications with retry logic, reusable for heartbeat alerts
- **Dashboard** (spec 009 complete) — module-aware sidebar, `SplitPane`/`FilterableList`/`DetailPanel` primitives, route slots for `/hooks`, `/forms`, `/heartbeats`, feature flag system via `/admin/status`
- **MCP server** — hexagonal tools + ports pattern, ready for new tools
- **ActionCable** — real-time WebSocket infrastructure with project/inbox channels
- **Event store** — domain events with publish/subscribe
- **TTL cleanup** — `EmailCleanupJob` pattern reusable for HTTP requests

### What this spec adds

- `http_endpoints` and `http_requests` database tables
- Domain entities, value objects, events, aggregates
- Public catch endpoint: `ANY /hook/:token`
- Management REST API under `/api/v1/endpoints/`
- Admin management under `/admin/endpoints/`
- Dashboard: three new module views (Hooks In, Forms, Heartbeats)
- 7 new MCP tools
- ActionCable channels for real-time updates
- Heartbeat monitoring background job
- Feature flag activation for `hooks`, `forms`, `heartbeats` modules

---

## 3. Data Model

### 3.1 Database Tables

#### `http_endpoints`

See [ADR-023](../adrs/023-endpoint-type-polymorphism.md) for the full schema rationale.

```sql
CREATE TABLE http_endpoints (
  id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id                UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  endpoint_type             VARCHAR NOT NULL DEFAULT 'webhook',
  token                     VARCHAR NOT NULL,
  label                     VARCHAR,
  description               TEXT,

  -- Request capture config
  allowed_methods           VARCHAR[] DEFAULT '{POST}',
  max_body_bytes            INTEGER DEFAULT 262144,

  -- Optional IP allowlist (ADR-025)
  allowed_ips               VARCHAR[],

  -- Form-specific
  response_mode             VARCHAR,
  response_redirect_url     VARCHAR,
  response_html             TEXT,

  -- Heartbeat-specific (ADR-024)
  expected_interval_seconds INTEGER,
  heartbeat_status          VARCHAR DEFAULT 'pending',
  last_ping_at              TIMESTAMPTZ,
  status_changed_at         TIMESTAMPTZ,

  -- Counters
  request_count             INTEGER DEFAULT 0,

  created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT http_endpoints_token_unique UNIQUE (token),
  CONSTRAINT http_endpoints_type_check CHECK (endpoint_type IN ('webhook', 'form', 'heartbeat')),
  CONSTRAINT http_endpoints_heartbeat_interval CHECK (
    endpoint_type != 'heartbeat' OR expected_interval_seconds > 0
  ),
  CONSTRAINT http_endpoints_response_mode_check CHECK (
    response_mode IS NULL OR response_mode IN ('json', 'redirect', 'html')
  )
);

CREATE INDEX idx_http_endpoints_project ON http_endpoints(project_id);
CREATE INDEX idx_http_endpoints_token ON http_endpoints(token);
CREATE INDEX idx_http_endpoints_type ON http_endpoints(project_id, endpoint_type);
CREATE INDEX idx_http_endpoints_heartbeat_status ON http_endpoints(heartbeat_status)
  WHERE endpoint_type = 'heartbeat';
```

#### `http_requests`

```sql
CREATE TABLE http_requests (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  http_endpoint_id    UUID NOT NULL REFERENCES http_endpoints(id) ON DELETE CASCADE,
  method              VARCHAR NOT NULL,
  path                VARCHAR,
  query_string        TEXT,
  headers             JSONB NOT NULL DEFAULT '{}',
  body                TEXT,
  content_type        VARCHAR,
  ip_address          VARCHAR,
  size_bytes          INTEGER DEFAULT 0,
  received_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at          TIMESTAMPTZ,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_http_requests_endpoint ON http_requests(http_endpoint_id, received_at DESC);
CREATE INDEX idx_http_requests_expires ON http_requests(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX idx_http_requests_method ON http_requests(http_endpoint_id, method);
```

### 3.2 Domain Layer

#### Value Objects

```ruby
# app/domain/value_objects/endpoint_type.rb
module Inboxed::Domain::ValueObjects
  EndpointType = Types::String.enum('webhook', 'form', 'heartbeat')
end

# app/domain/value_objects/heartbeat_status.rb
module Inboxed::Domain::ValueObjects
  HeartbeatStatus = Types::String.enum('pending', 'healthy', 'late', 'down')
end

# app/domain/value_objects/form_config.rb
module Inboxed::Domain::ValueObjects
  class FormConfig < Dry::Struct
    attribute :response_mode, Types::String.enum('json', 'redirect', 'html')
    attribute :redirect_url, Types::String.optional
    attribute :response_html, Types::String.optional
  end
end

# app/domain/value_objects/heartbeat_config.rb
module Inboxed::Domain::ValueObjects
  class HeartbeatConfig < Dry::Struct
    attribute :expected_interval_seconds, Types::Integer.constrained(gt: 0)
    attribute :status, HeartbeatStatus
    attribute :last_ping_at, Types::Time.optional
    attribute :status_changed_at, Types::Time.optional

    def evaluate(now: Time.current)
      return :pending if last_ping_at.nil?
      elapsed = now - last_ping_at
      if elapsed <= expected_interval_seconds
        :healthy
      elsif elapsed <= expected_interval_seconds * 2
        :late
      else
        :down
      end
    end
  end
end

# app/domain/value_objects/http_method.rb
module Inboxed::Domain::ValueObjects
  HttpMethod = Types::String.enum('GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS')
end

# app/domain/value_objects/captured_request.rb
module Inboxed::Domain::ValueObjects
  class CapturedRequest < Dry::Struct
    attribute :method, Types::String
    attribute :path, Types::String.optional
    attribute :query_string, Types::String.optional
    attribute :headers, Types::Hash
    attribute :body, Types::String.optional
    attribute :content_type, Types::String.optional
    attribute :ip_address, Types::String.optional
    attribute :size_bytes, Types::Integer
  end
end
```

#### Entity

```ruby
# app/domain/entities/http_endpoint.rb
module Inboxed::Domain::Entities
  class HttpEndpoint < Dry::Struct
    attribute :id, Types::UUID
    attribute :project_id, Types::UUID
    attribute :endpoint_type, ValueObjects::EndpointType
    attribute :token, Types::String
    attribute :label, Types::String.optional
    attribute :description, Types::String.optional
    attribute :allowed_methods, Types::Array.of(Types::String)
    attribute :max_body_bytes, Types::Integer
    attribute :allowed_ips, Types::Array.of(Types::String).optional
    attribute :request_count, Types::Integer
    attribute :created_at, Types::Time

    # Type-specific config (optional value objects)
    attribute :form_config, ValueObjects::FormConfig.optional
    attribute :heartbeat_config, ValueObjects::HeartbeatConfig.optional

    def webhook? = endpoint_type == 'webhook'
    def form?    = endpoint_type == 'form'
    def heartbeat? = endpoint_type == 'heartbeat'

    def accepts_method?(method)
      allowed_methods.include?(method.upcase)
    end

    def accepts_ip?(ip)
      return true if allowed_ips.nil? || allowed_ips.empty?
      allowed_ips.include?(ip)
    end
  end
end

# app/domain/entities/http_request.rb
module Inboxed::Domain::Entities
  class HttpRequest < Dry::Struct
    attribute :id, Types::UUID
    attribute :http_endpoint_id, Types::UUID
    attribute :method, Types::String
    attribute :path, Types::String.optional
    attribute :query_string, Types::String.optional
    attribute :headers, Types::Hash
    attribute :body, Types::String.optional
    attribute :content_type, Types::String.optional
    attribute :ip_address, Types::String.optional
    attribute :size_bytes, Types::Integer
    attribute :received_at, Types::Time
    attribute :expires_at, Types::Time.optional

    def json_body?
      content_type&.include?('application/json')
    end

    def form_data?
      content_type&.include?('application/x-www-form-urlencoded') ||
        content_type&.include?('multipart/form-data')
    end

    def parsed_json
      return nil unless json_body? && body.present?
      JSON.parse(body)
    rescue JSON::ParserError
      nil
    end

    def parsed_form_fields
      return nil unless form_data? && body.present?
      Rack::Utils.parse_nested_query(body)
    rescue
      nil
    end
  end
end
```

#### Domain Events

```ruby
# app/domain/events/http_request_captured.rb
module Inboxed::Domain::Events
  class HttpRequestCaptured < Inboxed::Domain::Events::Base
    attribute :endpoint_id, Types::UUID
    attribute :endpoint_type, Types::String
    attribute :request_id, Types::UUID
    attribute :project_id, Types::UUID
    attribute :method, Types::String
    attribute :path, Types::String.optional
    attribute :content_type, Types::String.optional
    attribute :size_bytes, Types::Integer
  end
end

# app/domain/events/http_endpoint_created.rb
module Inboxed::Domain::Events
  class HttpEndpointCreated < Inboxed::Domain::Events::Base
    attribute :endpoint_id, Types::UUID
    attribute :project_id, Types::UUID
    attribute :endpoint_type, Types::String
    attribute :token, Types::String
    attribute :label, Types::String.optional
  end
end

# app/domain/events/http_endpoint_deleted.rb
module Inboxed::Domain::Events
  class HttpEndpointDeleted < Inboxed::Domain::Events::Base
    attribute :endpoint_id, Types::UUID
    attribute :project_id, Types::UUID
    attribute :endpoint_type, Types::String
  end
end

# app/domain/events/heartbeat_status_changed.rb
module Inboxed::Domain::Events
  class HeartbeatStatusChanged < Inboxed::Domain::Events::Base
    attribute :endpoint_id, Types::UUID
    attribute :project_id, Types::UUID
    attribute :previous_status, Types::String
    attribute :new_status, Types::String
    attribute :last_ping_at, Types::Time.optional
    attribute :expected_interval_seconds, Types::Integer
  end
end
```

### 3.3 ActiveRecord Models (persistence only)

```ruby
# app/models/http_endpoint_record.rb
class HttpEndpointRecord < ApplicationRecord
  self.table_name = 'http_endpoints'

  belongs_to :project, class_name: 'ProjectRecord', foreign_key: 'project_id'
  has_many :http_requests, class_name: 'HttpRequestRecord',
           foreign_key: 'http_endpoint_id', dependent: :delete_all

  scope :by_type, ->(type) { where(endpoint_type: type) }
  scope :webhooks, -> { by_type('webhook') }
  scope :forms, -> { by_type('form') }
  scope :heartbeats, -> { by_type('heartbeat') }
  scope :active_heartbeats, -> { heartbeats.where.not(heartbeat_status: 'pending') }

  validates :endpoint_type, inclusion: { in: %w[webhook form heartbeat] }
  validates :token, presence: true, uniqueness: true
end

# app/models/http_request_record.rb
class HttpRequestRecord < ApplicationRecord
  self.table_name = 'http_requests'

  belongs_to :http_endpoint, class_name: 'HttpEndpointRecord', foreign_key: 'http_endpoint_id'

  validates :method, presence: true
end
```

---

## 4. Public Catch Endpoint

See [ADR-025](../adrs/025-public-catch-endpoint-security.md) for the full security model.

### 4.1 Routing

```ruby
# config/routes.rb (additions)
match '/hook/:token',       to: 'hooks#catch', via: :all
match '/hook/:token/*path', to: 'hooks#catch', via: :all
```

### 4.2 Controller

```ruby
# app/controllers/hooks_controller.rb
class HooksController < ActionController::API
  before_action :find_endpoint
  before_action :check_method_allowed
  before_action :check_ip_allowed
  before_action :check_body_size

  def catch
    result = Inboxed::Application::Services::CaptureHttpRequest.call(
      endpoint: @endpoint,
      request: build_captured_request
    )

    respond_to_endpoint_type(result)
  end

  private

  def find_endpoint
    @endpoint = HttpEndpointRecord.find_by(token: params[:token])
    head :not_found unless @endpoint
  end

  def check_method_allowed
    unless @endpoint.allowed_methods.include?(request.method)
      head :method_not_allowed
    end
  end

  def check_ip_allowed
    if @endpoint.allowed_ips.present? && !@endpoint.allowed_ips.include?(request.remote_ip)
      head :forbidden
    end
  end

  def check_body_size
    if request.content_length && request.content_length > @endpoint.max_body_bytes
      head :payload_too_large
    end
  end

  def build_captured_request
    {
      method: request.method,
      path: params[:path],
      query_string: request.query_string,
      headers: extract_headers,
      body: request.body.read(@endpoint.max_body_bytes),
      content_type: request.content_type,
      ip_address: request.remote_ip,
      size_bytes: request.content_length || 0
    }
  end

  def extract_headers
    request.headers.each_with_object({}) do |(key, value), hash|
      next unless key.start_with?('HTTP_') || %w[CONTENT_TYPE CONTENT_LENGTH].include?(key)
      normalized = key.sub(/^HTTP_/, '').tr('_', '-').downcase
      hash[normalized] = value
    end
  end

  def respond_to_endpoint_type(result)
    case @endpoint.endpoint_type
    when 'form'
      respond_as_form(result)
    when 'heartbeat'
      render json: { ok: true, status: result[:heartbeat_status] }
    else
      render json: { ok: true, id: result[:request_id] }
    end
  end

  def respond_as_form(result)
    case @endpoint.response_mode
    when 'redirect'
      redirect_to @endpoint.response_redirect_url, allow_other_host: true
    when 'html'
      render html: (@endpoint.response_html || default_thank_you_html).html_safe
    else
      render json: { ok: true, id: result[:request_id] }
    end
  end

  def default_thank_you_html
    <<~HTML
      <!DOCTYPE html>
      <html><head><title>Received</title></head>
      <body style="font-family:monospace;text-align:center;padding:4rem;">
        <h1>✓ Form received</h1>
        <p>Captured by <a href="https://github.com/your/inboxed">Inboxed</a></p>
      </body></html>
    HTML
  end
end
```

### 4.3 Application Service: CaptureHttpRequest

```ruby
# app/application/services/capture_http_request.rb
module Inboxed::Application::Services
  class CaptureHttpRequest
    def self.call(endpoint:, request:)
      new(endpoint:, request:).call
    end

    def initialize(endpoint:, request:)
      @endpoint = endpoint
      @request = request
    end

    def call
      # 1. Persist the captured request
      record = HttpRequestRecord.create!(
        http_endpoint_id: @endpoint.id,
        method: @request[:method],
        path: @request[:path],
        query_string: @request[:query_string],
        headers: @request[:headers],
        body: @request[:body],
        content_type: @request[:content_type],
        ip_address: @request[:ip_address],
        size_bytes: @request[:size_bytes],
        received_at: Time.current,
        expires_at: calculate_expiry
      )

      # 2. Increment request count
      HttpEndpointRecord.where(id: @endpoint.id)
        .update_all('request_count = request_count + 1')

      # 3. Update heartbeat state if applicable
      heartbeat_status = update_heartbeat_if_applicable

      # 4. Publish domain event
      publish_event(record)

      # 5. Broadcast real-time update
      broadcast_request(record)

      { request_id: record.id, heartbeat_status: heartbeat_status }
    end

    private

    def calculate_expiry
      project = ProjectRecord.find(@endpoint.project_id)
      Time.current + project.default_ttl_hours.hours
    end

    def update_heartbeat_if_applicable
      return nil unless @endpoint.endpoint_type == 'heartbeat'

      now = Time.current
      previous_status = @endpoint.heartbeat_status

      HttpEndpointRecord.where(id: @endpoint.id).update_all(
        last_ping_at: now,
        heartbeat_status: 'healthy',
        status_changed_at: (previous_status != 'healthy') ? now : @endpoint.status_changed_at,
        updated_at: now
      )

      if previous_status != 'healthy' && previous_status != 'pending'
        publish_heartbeat_recovery(previous_status)
      end

      'healthy'
    end

    def publish_event(record)
      Inboxed::Infrastructure::EventStore::Bus.publish(
        Inboxed::Domain::Events::HttpRequestCaptured.new(
          endpoint_id: @endpoint.id,
          endpoint_type: @endpoint.endpoint_type,
          request_id: record.id,
          project_id: @endpoint.project_id,
          method: record.method,
          path: record.path,
          content_type: record.content_type,
          size_bytes: record.size_bytes
        ),
        stream: "http_endpoint-#{@endpoint.id}"
      )
    end

    def publish_heartbeat_recovery(previous_status)
      Inboxed::Infrastructure::EventStore::Bus.publish(
        Inboxed::Domain::Events::HeartbeatStatusChanged.new(
          endpoint_id: @endpoint.id,
          project_id: @endpoint.project_id,
          previous_status: previous_status,
          new_status: 'healthy',
          last_ping_at: Time.current,
          expected_interval_seconds: @endpoint.expected_interval_seconds
        ),
        stream: "http_endpoint-#{@endpoint.id}"
      )
    end

    def broadcast_request(record)
      ActionCable.server.broadcast(
        "project_#{@endpoint.project_id}_http",
        {
          type: 'request_captured',
          endpoint_id: @endpoint.id,
          endpoint_type: @endpoint.endpoint_type,
          request: serialize_request(record)
        }
      )
    end

    def serialize_request(record)
      {
        id: record.id,
        method: record.method,
        path: record.path,
        content_type: record.content_type,
        ip_address: record.ip_address,
        size_bytes: record.size_bytes,
        received_at: record.received_at.iso8601
      }
    end
  end
end
```

---

## 5. Management REST API

### 5.1 Routes

```ruby
# config/routes.rb (additions)

namespace :api do
  namespace :v1 do
    resources :endpoints, param: :token, only: [:index, :create, :show, :update, :destroy] do
      resources :requests, only: [:index, :show, :destroy], module: :endpoints
      member do
        delete :purge     # delete all captured requests
      end
    end
  end
end

namespace :admin do
  resources :endpoints, param: :token, only: [:index, :create, :show, :update, :destroy] do
    resources :requests, only: [:index, :show, :destroy], module: :endpoints
    member do
      delete :purge
    end
  end
end
```

### 5.2 API Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/v1/endpoints` | List endpoints (filterable by `type`) |
| `POST` | `/api/v1/endpoints` | Create endpoint |
| `GET` | `/api/v1/endpoints/:token` | Show endpoint details |
| `PATCH` | `/api/v1/endpoints/:token` | Update endpoint config |
| `DELETE` | `/api/v1/endpoints/:token` | Delete endpoint and all requests |
| `DELETE` | `/api/v1/endpoints/:token/purge` | Delete all captured requests |
| `GET` | `/api/v1/endpoints/:token/requests` | List captured requests (cursor-paginated) |
| `GET` | `/api/v1/endpoints/:token/requests/:id` | Show request detail |
| `DELETE` | `/api/v1/endpoints/:token/requests/:id` | Delete a single request |

### 5.3 Request/Response Examples

#### Create webhook endpoint

```http
POST /api/v1/endpoints
Authorization: Bearer inx_abc123...
Content-Type: application/json

{
  "endpoint_type": "webhook",
  "label": "Stripe webhooks",
  "allowed_methods": ["POST"]
}
```

```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "type": "http_endpoint",
    "attributes": {
      "endpoint_type": "webhook",
      "token": "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk",
      "label": "Stripe webhooks",
      "url": "https://inboxed.dev/hook/dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk",
      "allowed_methods": ["POST"],
      "max_body_bytes": 262144,
      "request_count": 0,
      "created_at": "2026-03-16T12:00:00Z"
    }
  }
}
```

#### Create form endpoint

```http
POST /api/v1/endpoints
Authorization: Bearer inx_abc123...
Content-Type: application/json

{
  "endpoint_type": "form",
  "label": "Contact form",
  "response_mode": "redirect",
  "response_redirect_url": "https://myapp.test/thanks",
  "allowed_methods": ["POST"]
}
```

#### Create heartbeat endpoint

```http
POST /api/v1/endpoints
Authorization: Bearer inx_abc123...
Content-Type: application/json

{
  "endpoint_type": "heartbeat",
  "label": "cleanup-cron",
  "expected_interval_seconds": 300,
  "allowed_methods": ["POST", "GET"]
}
```

#### List captured requests

```http
GET /api/v1/endpoints/dBjftJeZ4CVP.../requests?limit=20
Authorization: Bearer inx_abc123...
```

```json
{
  "data": [
    {
      "id": "...",
      "type": "http_request",
      "attributes": {
        "method": "POST",
        "path": null,
        "content_type": "application/json",
        "ip_address": "54.187.174.169",
        "size_bytes": 1234,
        "received_at": "2026-03-16T12:05:00Z"
      }
    }
  ],
  "meta": {
    "total_count": 47,
    "next_cursor": "eyJpZCI6Ii..."
  }
}
```

#### Show request detail

```http
GET /api/v1/endpoints/dBjftJeZ4CVP.../requests/550e8400...
Authorization: Bearer inx_abc123...
```

```json
{
  "data": {
    "id": "550e8400...",
    "type": "http_request",
    "attributes": {
      "method": "POST",
      "path": "/checkout.completed",
      "query_string": "",
      "headers": {
        "content-type": "application/json",
        "stripe-signature": "t=1679...,v1=abc...",
        "user-agent": "Stripe/1.0 (+https://stripe.com/docs/webhooks)"
      },
      "body": "{\"id\":\"evt_1234\",\"type\":\"checkout.session.completed\",\"data\":{...}}",
      "content_type": "application/json",
      "ip_address": "54.187.174.169",
      "size_bytes": 1234,
      "received_at": "2026-03-16T12:05:00Z"
    }
  }
}
```

### 5.4 Controllers

Follow existing patterns from `Api::V1::BaseController`:

```ruby
# app/controllers/api/v1/endpoints_controller.rb
module Api
  module V1
    class EndpointsController < BaseController
      include Paginatable

      def index
        endpoints = Inboxed::ReadModels::EndpointList.call(
          project_id: current_project.id,
          endpoint_type: params[:type],
          **pagination_params
        )
        render json: serialize(endpoints)
      end

      def create
        result = Inboxed::Application::Services::CreateHttpEndpoint.call(
          project_id: current_project.id,
          params: endpoint_params
        )
        render json: serialize(result), status: :created
      end

      def show
        endpoint = Inboxed::ReadModels::EndpointDetail.call(
          token: params[:token],
          project_id: current_project.id
        )
        render json: serialize(endpoint)
      end

      def update
        result = Inboxed::Application::Services::UpdateHttpEndpoint.call(
          token: params[:token],
          project_id: current_project.id,
          params: endpoint_params
        )
        render json: serialize(result)
      end

      def destroy
        Inboxed::Application::Services::DeleteHttpEndpoint.call(
          token: params[:token],
          project_id: current_project.id
        )
        head :no_content
      end

      def purge
        Inboxed::Application::Services::PurgeHttpRequests.call(
          token: params[:token],
          project_id: current_project.id
        )
        head :no_content
      end

      private

      def endpoint_params
        params.permit(
          :endpoint_type, :label, :description,
          :max_body_bytes, :response_mode, :response_redirect_url,
          :response_html, :expected_interval_seconds,
          allowed_methods: [], allowed_ips: []
        )
      end
    end
  end
end

# app/controllers/api/v1/endpoints/requests_controller.rb
module Api
  module V1
    module Endpoints
      class RequestsController < BaseController
        include Paginatable

        def index
          requests = Inboxed::ReadModels::HttpRequestList.call(
            token: params[:endpoint_token],
            project_id: current_project.id,
            method: params[:method],
            **pagination_params
          )
          render json: serialize(requests)
        end

        def show
          request = Inboxed::ReadModels::HttpRequestDetail.call(
            id: params[:id],
            token: params[:endpoint_token],
            project_id: current_project.id
          )
          render json: serialize(request)
        end

        def destroy
          Inboxed::Application::Services::DeleteHttpRequest.call(
            id: params[:id],
            token: params[:endpoint_token],
            project_id: current_project.id
          )
          head :no_content
        end
      end
    end
  end
end
```

### 5.5 Read Models

```ruby
# app/read_models/inboxed/read_models/endpoint_list.rb
module Inboxed::ReadModels
  class EndpointList
    def self.call(project_id:, endpoint_type: nil, cursor: nil, limit: 20)
      scope = HttpEndpointRecord.where(project_id: project_id)
      scope = scope.by_type(endpoint_type) if endpoint_type
      scope = scope.order(created_at: :desc)
      # Cursor pagination (same pattern as InboxList)
      apply_cursor(scope, cursor:, limit:)
    end
  end
end

# app/read_models/inboxed/read_models/endpoint_detail.rb
module Inboxed::ReadModels
  class EndpointDetail
    def self.call(token:, project_id:)
      HttpEndpointRecord
        .where(project_id: project_id)
        .find_by!(token: token)
    end
  end
end

# app/read_models/inboxed/read_models/http_request_list.rb
module Inboxed::ReadModels
  class HttpRequestList
    def self.call(token:, project_id:, method: nil, cursor: nil, limit: 20)
      endpoint = HttpEndpointRecord.where(project_id: project_id).find_by!(token: token)
      scope = HttpRequestRecord.where(http_endpoint_id: endpoint.id)
      scope = scope.where(method: method.upcase) if method
      scope = scope.order(received_at: :desc)
      apply_cursor(scope, cursor:, limit:)
    end
  end
end

# app/read_models/inboxed/read_models/http_request_detail.rb
module Inboxed::ReadModels
  class HttpRequestDetail
    def self.call(id:, token:, project_id:)
      endpoint = HttpEndpointRecord.where(project_id: project_id).find_by!(token: token)
      HttpRequestRecord.where(http_endpoint_id: endpoint.id).find(id)
    end
  end
end
```

---

## 6. Real-Time

### 6.1 ActionCable Channel

```ruby
# app/channels/http_channel.rb
class HttpChannel < ApplicationCable::Channel
  def subscribed
    stream_from "project_#{params[:project_id]}_http"
  end
end
```

### 6.2 Events Broadcast

The `CaptureHttpRequest` service broadcasts to the channel (see section 4.3). Events:

| Event | Payload | When |
|---|---|---|
| `request_captured` | `{ endpoint_id, endpoint_type, request: { id, method, path, content_type, ip_address, size_bytes, received_at } }` | HTTP request captured |
| `endpoint_created` | `{ endpoint: { id, type, token, label } }` | Endpoint created via API |
| `endpoint_deleted` | `{ endpoint_id }` | Endpoint deleted |
| `requests_purged` | `{ endpoint_id, deleted_count }` | All requests purged |
| `heartbeat_status_changed` | `{ endpoint_id, previous_status, new_status }` | Heartbeat state transition |

### 6.3 Dashboard WebSocket Subscription

```typescript
// src/features/hooks/hooks.realtime.ts
import { websocketStore } from '$lib/stores/websocket.store.svelte';

export function subscribeToHttpEvents(projectId: string) {
  return websocketStore.subscribe(`project_${projectId}_http`, (event) => {
    switch (event.type) {
      case 'request_captured':
        // Prepend to request list, increment endpoint count
        // Fire toast: "POST /checkout.completed → Stripe webhooks"
        break;
      case 'heartbeat_status_changed':
        // Update heartbeat badge
        // Fire toast if status is 'down': "⚠ cleanup-cron is down"
        break;
    }
  });
}
```

---

## 7. Heartbeat Monitoring

See [ADR-024](../adrs/024-heartbeat-state-machine.md) for the full state machine design.

### 7.1 Background Job

```ruby
# app/application/jobs/heartbeat_check_job.rb
class HeartbeatCheckJob < ApplicationJob
  queue_as :default

  def perform
    Inboxed::Application::Services::CheckHeartbeats.call
  end
end
```

### 7.2 Recurring Schedule

```yaml
# config/recurring.yml (additions)
heartbeat_check:
  class: HeartbeatCheckJob
  schedule: every 30 seconds
```

### 7.3 CheckHeartbeats Service

```ruby
module Inboxed::Application::Services
  class CheckHeartbeats
    def self.call
      new.call
    end

    def call
      endpoints = HttpEndpointRecord.active_heartbeats.to_a
      return if endpoints.empty?

      now = Time.current

      endpoints.each do |endpoint|
        new_status = evaluate_status(endpoint, now)
        next if new_status == endpoint.heartbeat_status

        previous = endpoint.heartbeat_status
        endpoint.update!(
          heartbeat_status: new_status,
          status_changed_at: now
        )

        publish_status_change(endpoint, previous, new_status, now)
        fire_alert_if_down(endpoint, previous, new_status)
      end
    end

    private

    def evaluate_status(endpoint, now)
      return 'pending' if endpoint.last_ping_at.nil?

      elapsed = now - endpoint.last_ping_at
      interval = endpoint.expected_interval_seconds

      if elapsed <= interval
        'healthy'
      elsif elapsed <= interval * 2
        'late'
      else
        'down'
      end
    end

    def publish_status_change(endpoint, previous, new_status, now)
      Inboxed::Infrastructure::EventStore::Bus.publish(
        Inboxed::Domain::Events::HeartbeatStatusChanged.new(
          endpoint_id: endpoint.id,
          project_id: endpoint.project_id,
          previous_status: previous,
          new_status: new_status,
          last_ping_at: endpoint.last_ping_at,
          expected_interval_seconds: endpoint.expected_interval_seconds
        ),
        stream: "http_endpoint-#{endpoint.id}"
      )

      ActionCable.server.broadcast(
        "project_#{endpoint.project_id}_http",
        {
          type: 'heartbeat_status_changed',
          endpoint_id: endpoint.id,
          previous_status: previous,
          new_status: new_status
        }
      )
    end

    def fire_alert_if_down(endpoint, previous, new_status)
      # Fire webhook notifications via Phase 7 infrastructure
      if new_status == 'down' && previous != 'down'
        Inboxed::Application::Services::DispatchWebhookEvent.call(
          project_id: endpoint.project_id,
          event_type: 'heartbeat_down',
          payload: {
            endpoint_id: endpoint.id,
            label: endpoint.label,
            expected_interval_seconds: endpoint.expected_interval_seconds,
            last_ping_at: endpoint.last_ping_at&.iso8601
          }
        )
      elsif new_status == 'healthy' && %w[down late].include?(previous)
        Inboxed::Application::Services::DispatchWebhookEvent.call(
          project_id: endpoint.project_id,
          event_type: 'heartbeat_recovered',
          payload: {
            endpoint_id: endpoint.id,
            label: endpoint.label,
            last_ping_at: endpoint.last_ping_at&.iso8601
          }
        )
      end
    end
  end
end
```

### 7.4 New Webhook Event Types

Add to the existing webhook subscription system (spec 008):

```ruby
VALID_EVENT_TYPES = %w[
  email_received email_deleted inbox_created inbox_purged
  request_captured
  heartbeat_down heartbeat_recovered
]
```

---

## 8. TTL Cleanup

### 8.1 HttpRequestCleanupJob

Mirrors `EmailCleanupJob`:

```ruby
# app/application/jobs/http_request_cleanup_job.rb
class HttpRequestCleanupJob < ApplicationJob
  queue_as :default

  def perform
    deleted = HttpRequestRecord.where('expires_at < ?', Time.current).delete_all
    Rails.logger.info("HttpRequestCleanup: deleted #{deleted} expired requests")
  end
end
```

```yaml
# config/recurring.yml (additions)
http_request_cleanup:
  class: HttpRequestCleanupJob
  schedule: every 5 minutes
```

---

## 9. Dashboard

Spec 009 already provides the layout primitives (`SplitPane`, `FilterableList`, `DetailPanel`), module-aware sidebar, route slots, and feature flag system. This spec adds three feature modules that plug into that infrastructure.

### 9.1 Route Structure

```
src/routes/projects/[projectId]/
├── hooks/
│   ├── +page.svelte              → webhook endpoint list + request detail (SplitPane)
│   └── [endpointToken]/
│       └── +page.svelte          → single endpoint request list (SplitPane)
├── forms/
│   ├── +page.svelte              → form endpoint list + submission detail (SplitPane)
│   └── [endpointToken]/
│       └── +page.svelte          → single form submissions
├── heartbeats/
│   ├── +page.svelte              → heartbeat list with status badges (SplitPane)
│   └── [endpointToken]/
│       └── +page.svelte          → heartbeat detail with timeline
```

### 9.2 Module Registration

```typescript
// $lib/config/modules.ts (additions to existing registry)
{
  id: 'hooks',
  label: 'Hooks In',
  icon: 'webhook',
  route: (pid) => `/projects/${pid}/hooks`,
  countKey: 'webhook_count',
  enabled: true   // activated when Phase 8 ships
},
{
  id: 'forms',
  label: 'Forms',
  icon: 'description',
  route: (pid) => `/projects/${pid}/forms`,
  countKey: 'form_count',
  enabled: true
},
{
  id: 'heartbeats',
  label: 'Heartbeats',
  icon: 'favorite',
  route: (pid) => `/projects/${pid}/heartbeats`,
  countKey: 'heartbeat_count',
  enabled: true
}
```

### 9.3 Feature Directory Structure

```
src/features/
├── hooks/
│   ├── components/
│   │   ├── EndpointList.svelte        → FilterableList with type chips
│   │   ├── EndpointCard.svelte        → list item (token, label, count, type badge)
│   │   ├── RequestDetail.svelte       → DetailPanel wrapper for captured request
│   │   ├── RequestBodyViewer.svelte   → JSON pretty-print / raw toggle
│   │   ├── HeadersTable.svelte        → key-value table for headers
│   │   ├── FormFieldsTable.svelte     → parsed form fields for form endpoints
│   │   ├── HeartbeatTimeline.svelte   → ping timeline visualization
│   │   ├── HeartbeatStatusBadge.svelte → green/yellow/red badge
│   │   └── CreateEndpointDialog.svelte → create endpoint modal with type selector
│   ├── hooks.service.ts               → API calls for endpoints + requests
│   ├── hooks.store.svelte.ts          → endpoint + request state management
│   ├── hooks.realtime.ts              → WebSocket subscription (section 6.3)
│   └── hooks.types.ts                 → TypeScript interfaces
```

### 9.4 Key UI Components

#### Endpoint List View (Hooks In)

```
┌─ Hooks In ─────────────────────────────────────────────────────────────────┐
│  [All (12)] [Webhook (8)] [Form (3)] [Heartbeat (1)]    [+ Create]        │
│────────────────────────────────────────┬───────────────────────────────────│
│  🔗 Stripe webhooks          (23)     │  POST /checkout.completed          │
│     dBjftJ...  •  webhook             │  ─────────────────────────────────│
│  🔗 GitHub push events        (5)     │  Received: 2 minutes ago           │
│     aX7kMp...  •  webhook             │  IP: 54.187.174.169                │
│  📋 Contact form              (3)  ←  │  Size: 1,234 bytes                 │
│     rT9qWe...  •  form                │                                    │
│  💓 cleanup-cron         🟢 healthy   │  Headers                           │
│     yN2mLs...  •  heartbeat           │  ┌─────────────┬─────────────────┐ │
│                                        │  │ content-type│ application/json│ │
│                                        │  │ stripe-sig  │ t=1679...,v1=...│ │
│                                        │  └─────────────┴─────────────────┘ │
│                                        │                                    │
│                                        │  Body (JSON)                       │
│                                        │  ┌────────────────────────────────┐│
│                                        │  │ {                              ││
│                                        │  │   "id": "evt_1234",           ││
│                                        │  │   "type": "checkout.session..." ││
│                                        │  │ }                              ││
│                                        │  └────────────────────────────────┘│
└────────────────────────────────────────┴───────────────────────────────────┘
```

#### Heartbeat Detail View

```
┌─ Heartbeats ───────────────────────────────────────────────────────────────┐
│  💓 cleanup-cron                                               🟢 healthy │
│  Token: yN2mLs...  •  Expected: every 5m  •  Last ping: 2m ago            │
│────────────────────────────────────────────────────────────────────────────│
│  Timeline (last 24h)                                                       │
│  ████ ████ ████ ████ ████ ████ ░░░░ ████ ████ ████ ████ ████              │
│  12:00    14:00    16:00    18:00    20:00    22:00    00:00               │
│                              ↑ missed                                      │
│────────────────────────────────────────────────────────────────────────────│
│  Recent pings                                                              │
│  POST  •  54.187.174.169  •  2 minutes ago  •  0 bytes                    │
│  POST  •  54.187.174.169  •  7 minutes ago  •  0 bytes                    │
│  POST  •  54.187.174.169  •  12 minutes ago •  0 bytes                    │
│────────────────────────────────────────────────────────────────────────────│
│  Status history                                                            │
│  🟢 healthy  ←  🟡 late   at 18:35 (missed 1 ping)                        │
│  🟡 late     ←  🟢 healthy at 18:30                                        │
│  🟢 healthy  ←  ⬜ pending  at 12:00 (first ping)                          │
└────────────────────────────────────────────────────────────────────────────┘
```

#### Form Submission Detail

```
┌─ Form: Contact form ──────────────────────────────────────────────────────┐
│  [Fields] [Raw] [Headers]                                                  │
│────────────────────────────────────────────────────────────────────────────│
│  Form Fields                                                               │
│  ┌──────────────┬──────────────────────────────────┐                       │
│  │ name         │ John Doe                          │                       │
│  │ email        │ john@example.com                  │                       │
│  │ message      │ Hello, I'd like to learn more...  │                       │
│  │ newsletter   │ on                                │                       │
│  └──────────────┴──────────────────────────────────┘                       │
│                                                                            │
│  Metadata                                                                  │
│  Method: POST  •  IP: 192.168.1.1  •  2 minutes ago  •  234 bytes         │
│                                                                            │
│  HTML Snippet                                                              │
│  ┌────────────────────────────────────────────────────────────────┐ [Copy] │
│  │ <form action="https://inboxed.dev/hook/rT9qWe..." method="POST">│      │
│  │   <input name="name" />                                        │       │
│  │   <input name="email" type="email" />                          │       │
│  │   <textarea name="message"></textarea>                         │       │
│  │   <button type="submit">Send</button>                         │       │
│  │ </form>                                                        │       │
│  └────────────────────────────────────────────────────────────────┘        │
└────────────────────────────────────────────────────────────────────────────┘
```

### 9.5 Empty States

Using the `EmptyState` component from spec 009:

**No webhook endpoints:**
```
🔗 No webhook endpoints yet
Create an endpoint to start catching HTTP requests.

curl -X POST https://inboxed.dev/hook/<your-token> \
  -H "Content-Type: application/json" \
  -d '{"event": "test"}'

[+ Create Webhook Endpoint]
```

**No form endpoints:**
```
📋 No form endpoints yet
Create a form endpoint and point your HTML form at it.

<form action="https://inboxed.dev/hook/<token>" method="POST">
  <input name="email" />
  <button type="submit">Send</button>
</form>

[+ Create Form Endpoint]
```

**No heartbeat endpoints:**
```
💓 No heartbeat monitors yet
Create a heartbeat endpoint and ping it from your cron job.

# In your crontab:
*/5 * * * * curl -s https://inboxed.dev/hook/<token>

[+ Create Heartbeat]
```

### 9.6 Toast Integration

Wire real-time events to the toast system (spec 009):

```typescript
// On request_captured:
toastStore.add({
  type: 'success',
  title: `${method} request captured`,
  description: `${endpoint.label}${path ? ` ${path}` : ''}`,
  action: { label: 'View', href: `/projects/${projectId}/hooks/${endpoint.token}` }
});

// On heartbeat_status_changed to 'down':
toastStore.add({
  type: 'error',
  title: 'Heartbeat down',
  description: `${endpoint.label} missed expected ping`,
  duration: 0  // persistent — don't auto-dismiss
});

// On heartbeat_status_changed to 'healthy' (recovery):
toastStore.add({
  type: 'success',
  title: 'Heartbeat recovered',
  description: `${endpoint.label} is healthy again`
});
```

### 9.7 Command Palette Registration

```typescript
// Register commands for each endpoint
endpoints.forEach(ep => {
  commandStore.register({
    id: `goto-endpoint-${ep.id}`,
    label: `Go to "${ep.label}" (${ep.endpoint_type})`,
    category: 'navigation',
    icon: iconForType(ep.endpoint_type),
    keywords: [ep.label, ep.token, ep.endpoint_type],
    execute: () => goto(`/projects/${ep.project_id}/${routeForType(ep.endpoint_type)}/${ep.token}`)
  });
});

// Actions
commandStore.register({
  id: 'create-endpoint',
  label: 'Create HTTP endpoint',
  category: 'action',
  icon: 'add',
  keywords: ['webhook', 'form', 'heartbeat', 'hook', 'create', 'new'],
  execute: () => openCreateEndpointDialog()
});
```

---

## 10. MCP Tools

### 10.1 New Tools

Seven new tools added to the MCP server (`apps/mcp/`):

```typescript
// apps/mcp/src/tools/create-endpoint.ts
{
  name: 'create_endpoint',
  description: 'Create an HTTP endpoint to catch webhook requests, form submissions, or heartbeat pings',
  inputSchema: {
    type: 'object',
    properties: {
      project: { type: 'string', description: 'Project slug or ID' },
      endpoint_type: { type: 'string', enum: ['webhook', 'form', 'heartbeat'], default: 'webhook' },
      label: { type: 'string', description: 'Human-readable label' },
      expected_interval_seconds: { type: 'number', description: 'For heartbeat type: expected ping interval in seconds' }
    },
    required: ['project']
  }
}
// Returns: { token, url, endpoint_type, label }

// apps/mcp/src/tools/wait-for-request.ts
{
  name: 'wait_for_request',
  description: 'Wait for an HTTP request to arrive at an endpoint (long-poll, up to 30s)',
  inputSchema: {
    type: 'object',
    properties: {
      endpoint_token: { type: 'string', description: 'Endpoint token' },
      method: { type: 'string', description: 'Filter by HTTP method (e.g., POST)' },
      path_pattern: { type: 'string', description: 'Filter by path pattern (e.g., /stripe/*)' },
      timeout_seconds: { type: 'number', default: 30, description: 'Max seconds to wait' }
    },
    required: ['endpoint_token']
  }
}
// Returns: { id, method, path, headers, body, content_type, ip_address, received_at }

// apps/mcp/src/tools/get-latest-request.ts
{
  name: 'get_latest_request',
  description: 'Get the most recent HTTP request captured by an endpoint',
  inputSchema: {
    type: 'object',
    properties: {
      endpoint_token: { type: 'string' },
      method: { type: 'string', description: 'Filter by method' }
    },
    required: ['endpoint_token']
  }
}

// apps/mcp/src/tools/extract-json-field.ts
{
  name: 'extract_json_field',
  description: 'Extract a value from the JSON body of the latest request using a dot-notation path',
  inputSchema: {
    type: 'object',
    properties: {
      endpoint_token: { type: 'string' },
      json_path: { type: 'string', description: 'Dot-notation path (e.g., "data.object.id", "items[0].name")' }
    },
    required: ['endpoint_token', 'json_path']
  }
}
// Returns: { value, path, request_id }

// apps/mcp/src/tools/list-requests.ts
{
  name: 'list_requests',
  description: 'List captured HTTP requests for an endpoint',
  inputSchema: {
    type: 'object',
    properties: {
      endpoint_token: { type: 'string' },
      limit: { type: 'number', default: 10 },
      method: { type: 'string' }
    },
    required: ['endpoint_token']
  }
}

// apps/mcp/src/tools/check-heartbeat.ts
{
  name: 'check_heartbeat',
  description: 'Check the status of a heartbeat endpoint',
  inputSchema: {
    type: 'object',
    properties: {
      endpoint_token: { type: 'string' }
    },
    required: ['endpoint_token']
  }
}
// Returns: { status, last_ping_at, expected_interval, next_expected_at, label }

// apps/mcp/src/tools/delete-endpoint.ts
{
  name: 'delete_endpoint',
  description: 'Delete an HTTP endpoint and all its captured requests',
  inputSchema: {
    type: 'object',
    properties: {
      endpoint_token: { type: 'string' }
    },
    required: ['endpoint_token']
  }
}
```

### 10.2 Port Interface

```typescript
// apps/mcp/src/ports/inboxed-api.ts (additions)
export interface InboxedApiPort {
  // ... existing email methods ...

  // HTTP endpoints
  createEndpoint(params: CreateEndpointParams): Promise<Endpoint>;
  getEndpoint(token: string): Promise<Endpoint>;
  listEndpoints(params: ListEndpointsParams): Promise<PaginatedResponse<Endpoint>>;
  deleteEndpoint(token: string): Promise<void>;

  // HTTP requests
  listRequests(token: string, params: ListRequestsParams): Promise<PaginatedResponse<HttpRequest>>;
  getRequest(token: string, requestId: string): Promise<HttpRequest>;
  getLatestRequest(token: string, method?: string): Promise<HttpRequest | null>;
  waitForRequest(token: string, params: WaitParams): Promise<HttpRequest>;
}
```

---

## 11. API Response: Feature Flags

Update the `/admin/status` (and `/api/v1/status`) response to activate HTTP catcher modules:

```json
{
  "status": "ok",
  "version": "1.1.0",
  "mode": "standalone",
  "features": {
    "mail": true,
    "hooks": true,
    "forms": true,
    "heartbeats": true,
    "mcp": true
  }
}
```

The feature flags are controlled by environment variables:

```bash
INBOXED_FEATURE_HOOKS=true       # default: true (when Phase 8 ships)
INBOXED_FEATURE_FORMS=true       # default: true
INBOXED_FEATURE_HEARTBEATS=true  # default: true
```

Users can disable modules they don't need. The dashboard sidebar and tab bar respect these flags (spec 009 infrastructure).

---

## 12. Rate Limiting

Extend existing Rack::Attack configuration (spec 003):

```ruby
# config/initializers/rack_attack.rb (additions)

# Public catch endpoint — per token
Rack::Attack.throttle("hook/per_token", limit: 120, period: 60) do |req|
  if req.path.start_with?("/hook/")
    req.path.match(%r{^/hook/([^/]+)})&.captures&.first
  end
end

# Public catch endpoint — global
Rack::Attack.throttle("hook/global", limit: 1000, period: 60) do |req|
  "global" if req.path.start_with?("/hook/")
end

# Management API — same rules as existing API endpoints
# (already covered by existing api/v1 throttle rules)
```

---

## 13. Technical Decisions

### 13.1 Single Table vs Multi-Table for Endpoint Types

- **Options:** A) Separate tables per type, B) Single table with type column, C) Single table with JSONB
- **Chosen:** B — Single `http_endpoints` table
- **Why:** One token lookup, one management API, shared infrastructure. See [ADR-023](../adrs/023-endpoint-type-polymorphism.md).
- **Trade-offs:** 4 nullable columns for type-specific fields. Mitigated by CHECK constraints.

### 13.2 Heartbeat Detection: Polling vs Per-Endpoint Jobs

- **Options:** A) Polling job every 30s, B) Per-endpoint scheduled jobs, C) Hybrid
- **Chosen:** A — Polling
- **Why:** Simpler, adequate for dev tool scale (< 100 heartbeats). See [ADR-024](../adrs/024-heartbeat-state-machine.md).
- **Trade-offs:** Up to 30s detection latency. Acceptable.

### 13.3 Public Endpoint Security

- **Options:** A) Token-only, B) Token + IP allowlist, C) Token + HMAC verification
- **Chosen:** B — Token + optional IP allowlist
- **Why:** Zero-friction default, extra security when needed. HMAC would require per-provider adapters. See [ADR-025](../adrs/025-public-catch-endpoint-security.md).
- **Trade-offs:** No signature verification — users can do this in test code after extraction.

### 13.4 Body Storage: Text vs Binary

- **Options:** A) Store body as TEXT, B) Store as BYTEA
- **Chosen:** A — TEXT column
- **Why:** The vast majority of webhook payloads are text (JSON, form data, XML). Storing as TEXT enables PostgreSQL full-text search and JSON operators (`body::jsonb ->> 'key'`). Binary payloads (rare for webhooks) are stored as base64.
- **Trade-offs:** Binary payloads inflate ~33% due to base64 encoding. Acceptable — max body is 256KB, and binary webhook payloads are extremely rare.

### 13.5 Wait Endpoint for MCP

- **Options:** A) Reuse email wait pattern (long-poll via API), B) WebSocket-based wait
- **Chosen:** A — Long-poll via API
- **Why:** Same proven pattern as email `wait_for_email`. MCP tools are request/response — WebSocket doesn't fit the model. Polls every 500ms for up to `timeout_seconds`.
- **Trade-offs:** Slightly higher server load than WebSocket, but bounded by timeout and acceptable for dev tool.

### 13.6 Separate Routes per Type vs Unified

- **Options:** A) `/projects/[id]/hooks`, `/projects/[id]/forms`, `/projects/[id]/heartbeats` (separate), B) `/projects/[id]/endpoints?type=webhook` (unified)
- **Chosen:** A — Separate routes
- **Why:** Each type has distinct UI (JSON viewer vs field table vs timeline). Separate routes allow independent page components and navigation. Aligns with VISION.md module naming. Sidebar shows each as a distinct module.
- **Trade-offs:** Three route trees instead of one. Mitigated by shared components and a single API/service layer.

---

## 14. Implementation Plan

### Step 1: Database & Domain Layer

1. Create migration for `http_endpoints` table
2. Create migration for `http_requests` table
3. Create `HttpEndpointRecord` and `HttpRequestRecord` AR models
4. Create domain value objects: `EndpointType`, `HeartbeatStatus`, `FormConfig`, `HeartbeatConfig`, `CapturedRequest`
5. Create domain entities: `HttpEndpoint`, `HttpRequest`
6. Create domain events: `HttpRequestCaptured`, `HttpEndpointCreated`, `HttpEndpointDeleted`, `HeartbeatStatusChanged`
7. Create repository: `HttpEndpointRepository`, `HttpRequestRepository`
8. Run migrations, verify schema

### Step 2: Public Catch Endpoint

1. Create `HooksController` with `catch` action
2. Add routes: `match '/hook/:token'` and `match '/hook/:token/*path'`
3. Create `CaptureHttpRequest` application service
4. Implement method checking, IP allowlist, body size enforcement
5. Implement form response modes (json, redirect, html)
6. Implement heartbeat status update on ping
7. Add rate limiting rules for `/hook/` path
8. **Verify:** `curl -X POST http://localhost:3000/hook/<token> -d '{"test": true}'` → 200 OK, request persisted

### Step 3: Management REST API

1. Create `Api::V1::EndpointsController` (CRUD)
2. Create `Api::V1::Endpoints::RequestsController` (list, show, delete)
3. Create `Admin::EndpointsController` and `Admin::Endpoints::RequestsController`
4. Create read models: `EndpointList`, `EndpointDetail`, `HttpRequestList`, `HttpRequestDetail`
5. Create application services: `CreateHttpEndpoint`, `UpdateHttpEndpoint`, `DeleteHttpEndpoint`, `PurgeHttpRequests`, `DeleteHttpRequest`
6. Add routes
7. **Verify:** Full CRUD via `curl`, cursor pagination works, filter by type works

### Step 4: Real-Time & Events

1. Create `HttpChannel` for ActionCable
2. Wire `CaptureHttpRequest` to broadcast events
3. Wire `CreateHttpEndpoint` and `DeleteHttpEndpoint` to broadcast
4. Register `request_captured` as a new webhook event type (Phase 7)
5. **Verify:** Create endpoint → capture request → ActionCable event arrives in browser console

### Step 5: Heartbeat Monitoring

1. Create `HeartbeatCheckJob`
2. Add to `config/recurring.yml`
3. Create `CheckHeartbeats` application service
4. Add `heartbeat_down` and `heartbeat_recovered` to webhook event types
5. Wire status changes to ActionCable broadcasts
6. **Verify:** Create heartbeat with 60s interval → send ping → wait 2 minutes → status transitions to `late` → wait 2 more minutes → transitions to `down` → send ping → recovers to `healthy`

### Step 6: TTL Cleanup

1. Create `HttpRequestCleanupJob`
2. Add to `config/recurring.yml`
3. **Verify:** Create request with short TTL → wait → request deleted by cleanup job

### Step 7: Dashboard — Hooks In Module

1. Create feature directory `src/features/hooks/`
2. Create `hooks.service.ts` (API client methods)
3. Create `hooks.store.svelte.ts` (state management)
4. Create `hooks.types.ts` (TypeScript interfaces)
5. Create `hooks.realtime.ts` (WebSocket subscription)
6. Create components: `EndpointList`, `EndpointCard`, `RequestDetail`, `RequestBodyViewer`, `HeadersTable`, `CreateEndpointDialog`
7. Create route pages: `/projects/[id]/hooks/+page.svelte`, `/projects/[id]/hooks/[token]/+page.svelte`
8. Wire to `SplitPane` + `FilterableList` + `DetailPanel` (spec 009 primitives)
9. Register module in sidebar and tab bar
10. Add empty state for no endpoints
11. Wire toast notifications for `request_captured`
12. Register command palette commands
13. **Verify:** Create endpoint in dashboard → send curl → request appears in real-time → detail view shows JSON pretty-printed

### Step 8: Dashboard — Forms Module

1. Create route pages: `/projects/[id]/forms/+page.svelte`, `/projects/[id]/forms/[token]/+page.svelte`
2. Create `FormFieldsTable.svelte` — parses form data into key-value table
3. Create HTML snippet generator component
4. Add form-specific empty state with HTML form example
5. Register module in sidebar
6. **Verify:** Create form endpoint → submit HTML form → fields rendered in table → HTML snippet is correct and copyable

### Step 9: Dashboard — Heartbeats Module

1. Create route pages: `/projects/[id]/heartbeats/+page.svelte`, `/projects/[id]/heartbeats/[token]/+page.svelte`
2. Create `HeartbeatStatusBadge.svelte` (green/yellow/red)
3. Create `HeartbeatTimeline.svelte` (24h ping visualization)
4. Add heartbeat-specific empty state with cron example
5. Wire status change events to badge updates and toasts
6. Register module in sidebar
7. **Verify:** Create heartbeat → ping it → see healthy badge → stop pinging → see transition to late → then down → toast appears

### Step 10: MCP Tools

1. Create tool files: `create-endpoint.ts`, `wait-for-request.ts`, `get-latest-request.ts`, `extract-json-field.ts`, `list-requests.ts`, `check-heartbeat.ts`, `delete-endpoint.ts`
2. Add port methods to `InboxedApiPort` interface
3. Implement port adapter methods
4. Register tools in MCP server
5. **Verify:** Claude Code can `create_endpoint` → send curl to URL → `get_latest_request` → `extract_json_field("data.id")` returns correct value

### Step 11: Feature Flags & Integration

1. Update `/admin/status` and `/api/v1/status` to include `hooks`, `forms`, `heartbeats` in features map
2. Add environment variables `INBOXED_FEATURE_HOOKS`, `INBOXED_FEATURE_FORMS`, `INBOXED_FEATURE_HEARTBEATS`
3. Ensure sidebar hides modules when disabled
4. Ensure API returns 404 for disabled module endpoints
5. **Verify:** Set `INBOXED_FEATURE_FORMS=false` → forms tab hidden, form API returns 404

### Step 12: Polish & Testing

1. RSpec tests for all application services
2. RSpec tests for public catch endpoint (all methods, all response types)
3. RSpec tests for management API (CRUD, pagination, auth)
4. RSpec tests for heartbeat state machine
5. RSpec tests for TTL cleanup
6. Vitest tests for dashboard components
7. Vitest tests for MCP tools
8. Integration test: create endpoint → curl → toast → API → MCP extract
9. `bundle exec standardrb` — zero offenses
10. `svelte-check` — zero errors
11. `eslint` — zero errors

---

## 15. Exit Criteria

### Public Catch Endpoint

- [x] **EC-001:** `POST /hook/:token` with JSON body → 200 OK, request persisted in `http_requests`
- [x] **EC-002:** `GET /hook/:token` (when GET is allowed) → 200 OK, request persisted
- [x] **EC-003:** Request with disallowed method → 405 Method Not Allowed
- [x] **EC-004:** Request with body > `max_body_bytes` → 413 Payload Too Large
- [x] **EC-005:** Request from non-allowlisted IP (when allowlist is set) → 403 Forbidden
- [x] **EC-006:** Invalid token → 404 Not Found
- [x] **EC-007:** Form endpoint with redirect mode → 302 to configured URL
- [x] **EC-008:** Form endpoint with HTML mode → 200 with thank-you page
- [x] **EC-009:** Heartbeat endpoint ping → 200 with `{"ok": true, "status": "healthy"}`
- [x] **EC-010:** Sub-path capture: `POST /hook/:token/stripe/checkout` stores path `stripe/checkout`
- [x] **EC-011:** Rate limiting: > 120 requests/minute to single token → 429

### Management API

- [x] **EC-012:** `POST /api/v1/endpoints` creates webhook endpoint with generated token
- [x] **EC-013:** `POST /api/v1/endpoints` creates form endpoint with response config
- [x] **EC-014:** `POST /api/v1/endpoints` creates heartbeat endpoint with interval
- [x] **EC-015:** `GET /api/v1/endpoints?type=webhook` returns only webhook endpoints
- [x] **EC-016:** `GET /api/v1/endpoints/:token/requests` returns cursor-paginated requests
- [x] **EC-017:** `DELETE /api/v1/endpoints/:token/purge` deletes all requests, keeps endpoint
- [x] **EC-018:** `DELETE /api/v1/endpoints/:token` deletes endpoint and all requests
- [x] **EC-019:** Admin endpoints mirror API endpoints with admin auth
- [x] **EC-020:** API returns endpoint `url` field with full catch URL

### Real-Time

- [x] **EC-021:** Captured request triggers ActionCable event within 1s
- [x] **EC-022:** Dashboard list updates without page refresh
- [x] **EC-023:** Toast notification appears for captured request
- [x] **EC-024:** Heartbeat status change triggers ActionCable event

### Heartbeat Monitoring

- [x] **EC-025:** New heartbeat endpoint starts in `pending` status
- [x] **EC-026:** First ping transitions to `healthy`
- [x] **EC-027:** No ping for 1x interval transitions to `late`
- [x] **EC-028:** No ping for 2x interval transitions to `down`
- [x] **EC-029:** Ping after `down` transitions to `healthy`
- [x] **EC-030:** Transition to `down` fires `heartbeat_down` webhook notification
- [x] **EC-031:** Recovery fires `heartbeat_recovered` webhook notification
- [x] **EC-032:** `HeartbeatCheckJob` runs every 30 seconds

### Dashboard

- [x] **EC-033:** Hooks In module visible in sidebar and tab bar
- [x] **EC-034:** Forms module visible in sidebar and tab bar (via type filter pills)
- [x] **EC-035:** Heartbeats module visible in sidebar and tab bar (via type filter pills)
- [x] **EC-036:** Endpoint list shows type badges, labels, and request counts
- [x] **EC-037:** Request detail shows method, headers table, body (JSON pretty-printed or raw)
- [x] **EC-038:** Form request detail shows parsed field table
- [ ] **EC-039:** Form endpoint detail shows copyable HTML snippet
- [x] **EC-040:** Heartbeat detail shows status badge, timeline, and status history
- [x] **EC-041:** Create endpoint dialog with type selector works for all three types
- [ ] **EC-042:** Empty states show type-specific onboarding with copy-pasteable examples
- [x] **EC-043:** Modules hidden when feature flag is disabled

### MCP

- [x] **EC-044:** `create_endpoint` returns token and full catch URL
- [x] **EC-045:** `wait_for_request` blocks until request arrives (up to timeout)
- [x] **EC-046:** `get_latest_request` returns most recent request with full body
- [x] **EC-047:** `extract_json_field` extracts nested value from JSON body
- [x] **EC-048:** `list_requests` returns paginated list of requests
- [x] **EC-049:** `check_heartbeat` returns current status and timing info
- [x] **EC-050:** `delete_endpoint` removes endpoint and all requests

### TTL & Cleanup

- [x] **EC-051:** Expired HTTP requests are deleted by cleanup job
- [x] **EC-052:** Endpoint deletion cascades to all associated requests

### Integration

- [ ] **EC-053:** Full flow: create endpoint → curl POST → toast → list update → API read → MCP extract
- [ ] **EC-054:** Full heartbeat flow: create → ping → stop → late → down → alert → ping → recover
- [ ] **EC-055:** Full form flow: create form endpoint → submit HTML form → fields in dashboard → snippet is correct
- [ ] **EC-056:** `bundle exec standardrb` passes
- [ ] **EC-057:** `svelte-check` passes
- [x] **EC-058:** All RSpec and Vitest tests pass

---

## 16. Open Questions

1. **Request body search:** Should we add full-text search on HTTP request bodies (like email search)? Recommendation: not in this spec — body search is complex for JSON. Revisit if users request it. The `extract_json_field` MCP tool covers the AI agent use case.

2. **Webhook replay:** Should the dashboard have a "Replay" button to re-send a captured request to a different URL? Recommendation: defer to Phase 7 post-MVP features ("Hooks Out" module in VISION.md). This spec is about catching, not sending.

3. **File upload storage for form endpoints:** Multipart form data may include file uploads. Should we store files as attachments (like email attachments) or just store the raw body? Recommendation: store the raw multipart body. If file extraction becomes important, add it later — the raw data is preserved.

4. **Max endpoints per project:** Should we limit the number of endpoints per project? Recommendation: yes, configurable via `max_endpoint_count` on project (default: 50). Mirrors `max_inbox_count` for emails.

5. **Heartbeat grace period:** Should new heartbeat endpoints have a grace period before they can transition to `late`/`down`? Current design: they stay in `pending` until the first ping, then the clock starts. This seems sufficient — no grace period needed.
