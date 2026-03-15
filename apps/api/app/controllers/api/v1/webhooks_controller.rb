# frozen_string_literal: true

module Api
  module V1
    class WebhooksController < BaseController
      def index
        repo = Inboxed::Repositories::WebhookEndpointRepository.new
        endpoints = repo.list_for_project(@current_project.id)
        render json: {
          data: endpoints.map { |e| WebhookEndpointSerializer.render(e) }
        }
      end

      def show
        endpoint = find_endpoint
        delivery_repo = Inboxed::Repositories::WebhookDeliveryRepository.new
        stats = delivery_repo.stats_for_endpoint(endpoint.id)
        render json: {
          data: WebhookEndpointSerializer.render_with_stats(endpoint, stats)
        }
      end

      def create
        repo = Inboxed::Repositories::WebhookEndpointRepository.new
        endpoint = repo.create(
          project_id: @current_project.id,
          url: params.require(:url),
          event_types: params.require(:event_types),
          description: params[:description]
        )
        render json: {
          data: WebhookEndpointSerializer.render(endpoint, include_secret: true)
        }, status: :created
      end

      def update
        endpoint = find_endpoint
        repo = Inboxed::Repositories::WebhookEndpointRepository.new
        allowed = params.permit(:url, :description, :status, event_types: [])
        repo.update(endpoint, allowed.to_h.compact)
        render json: {
          data: WebhookEndpointSerializer.render(endpoint)
        }
      end

      def destroy
        endpoint = find_endpoint
        repo = Inboxed::Repositories::WebhookEndpointRepository.new
        repo.destroy(endpoint)
        head :no_content
      end

      def test
        endpoint = find_endpoint
        result = send_test_delivery(endpoint)
        render json: {data: result}
      end

      private

      def find_endpoint
        WebhookEndpointRecord.find_by!(
          id: params[:id],
          project_id: @current_project.id
        )
      end

      def send_test_delivery(endpoint)
        timestamp = Time.current.to_i
        payload = {
          event: "email_received",
          event_id: "test_#{SecureRandom.hex(8)}",
          timestamp: Time.current.iso8601,
          data: {
            email_id: SecureRandom.uuid,
            inbox_id: SecureRandom.uuid,
            inbox_address: "test@example.com",
            from: "noreply@inboxed.dev",
            to: ["test@example.com"],
            subject: "Inboxed test webhook",
            preview: "This is a test delivery from Inboxed.",
            received_at: Time.current.iso8601
          }
        }

        body = payload.to_json
        signature = Inboxed::Webhooks::Signer.sign(endpoint.secret, timestamp, body)

        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        response = deliver_test(endpoint.url, body, timestamp, signature)
        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round

        if response[:success]
          {success: true, http_status: response[:status], duration_ms: duration_ms}
        else
          {success: false, http_status: response[:status], error: response[:body]&.truncate(200)}
        end
      end

      def deliver_test(url, body, timestamp, signature)
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        http.open_timeout = 10
        http.read_timeout = 10

        request = Net::HTTP::Post.new(uri.request_uri)
        request["Content-Type"] = "application/json"
        request["User-Agent"] = "Inboxed-Webhook/1.0"
        request["X-Inboxed-Event"] = "email_received"
        request["X-Inboxed-Delivery"] = "test"
        request["X-Inboxed-Timestamp"] = timestamp.to_s
        request["X-Inboxed-Signature"] = signature
        request.body = body

        response = http.request(request)
        {success: response.code.to_i.between?(200, 299), status: response.code.to_i, body: response.body}
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError => e
        {success: false, status: nil, body: e.message}
      end
    end
  end
end
