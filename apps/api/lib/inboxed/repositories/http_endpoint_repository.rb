# frozen_string_literal: true

module Inboxed
  module Repositories
    class HttpEndpointRepository
      def find_by_token(token, project_id: nil)
        scope = HttpEndpointRecord
        scope = scope.where(project_id: project_id) if project_id
        record = scope.find_by!(token: token)
        to_entity(record)
      end

      def list_for_project(project_id, endpoint_type: nil)
        scope = HttpEndpointRecord.where(project_id: project_id)
        scope = scope.by_type(endpoint_type) if endpoint_type
        scope.order(created_at: :desc).map { |r| to_entity(r) }
      end

      def create(project_id:, params:)
        record = HttpEndpointRecord.create!(
          project_id: project_id,
          endpoint_type: params[:endpoint_type] || "webhook",
          label: params[:label],
          description: params[:description],
          allowed_methods: params[:allowed_methods] || HttpEndpointRecord::VALID_HTTP_METHODS,
          allowed_ips: params[:allowed_ips] || [],
          max_body_bytes: params[:max_body_bytes] || 262_144,
          response_mode: params[:response_mode],
          response_redirect_url: params[:response_redirect_url],
          response_html: params[:response_html],
          expected_interval_seconds: params[:expected_interval_seconds],
          heartbeat_status: (params[:endpoint_type] == "heartbeat") ? "pending" : nil
        )
        to_entity(record)
      end

      def update(token, project_id:, params:)
        record = HttpEndpointRecord.where(project_id: project_id).find_by!(token: token)
        record.update!(params.except(:endpoint_type, :token))
        to_entity(record)
      end

      def destroy(token, project_id:)
        record = HttpEndpointRecord.where(project_id: project_id).find_by!(token: token)
        record.destroy!
      end

      def active_heartbeats
        HttpEndpointRecord.active_heartbeats.map { |r| to_entity(r) }
      end

      private

      def to_entity(record)
        form_config = if record.endpoint_type == "form" && record.response_mode
          ValueObjects::FormConfig.new(
            response_mode: record.response_mode,
            redirect_url: record.response_redirect_url,
            response_html: record.response_html
          )
        end

        heartbeat_config = if record.endpoint_type == "heartbeat"
          ValueObjects::HeartbeatConfig.new(
            expected_interval_seconds: record.expected_interval_seconds || 300,
            status: record.heartbeat_status || "pending",
            last_ping_at: record.last_ping_at,
            status_changed_at: record.status_changed_at
          )
        end

        Entities::HttpEndpoint.new(
          id: record.id,
          project_id: record.project_id,
          endpoint_type: record.endpoint_type,
          token: record.token,
          label: record.label,
          description: record.description,
          allowed_methods: record.allowed_methods || [],
          max_body_bytes: record.max_body_bytes || 262_144,
          allowed_ips: record.allowed_ips || [],
          request_count: record.request_count || 0,
          created_at: record.created_at,
          form_config: form_config,
          heartbeat_config: heartbeat_config
        )
      end
    end
  end
end
