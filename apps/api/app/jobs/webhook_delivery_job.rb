# frozen_string_literal: true

class WebhookDeliveryJob < ApplicationJob
  queue_as :webhooks

  TIMEOUT = 10
  MAX_ATTEMPTS = 6
  RETRY_DELAYS = [1.minute, 5.minutes, 30.minutes, 2.hours, 12.hours].freeze

  def perform(delivery_id)
    delivery_repo = Inboxed::Repositories::WebhookDeliveryRepository.new
    endpoint_repo = Inboxed::Repositories::WebhookEndpointRepository.new

    delivery = delivery_repo.find(delivery_id)
    endpoint = endpoint_repo.find(delivery.webhook_endpoint_id)

    return if endpoint.status == "disabled"

    timestamp = Time.current.to_i
    body = delivery.payload.to_json
    signature = Inboxed::Webhooks::Signer.sign(endpoint.secret, timestamp, body)

    response = make_request(endpoint.url, body, timestamp, signature, delivery.id)

    if response[:success]
      delivery_repo.mark_delivered(delivery,
        http_status: response[:status],
        response_body: response[:body])
      endpoint_repo.record_success(endpoint)
    else
      attempt = delivery.attempt_count + 1
      next_retry = (attempt < MAX_ATTEMPTS) ? RETRY_DELAYS[attempt - 1] : nil

      delivery_repo.mark_attempt_failed(delivery,
        http_status: response[:status],
        response_body: response[:body],
        next_retry_at: next_retry ? Time.current + next_retry : nil)

      endpoint_repo.record_failure(endpoint)

      if next_retry
        self.class.set(wait: next_retry).perform_later(delivery_id)
      end
    end
  end

  private

  def make_request(url, body, timestamp, signature, delivery_id)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request["User-Agent"] = "Inboxed-Webhook/1.0"
    request["X-Inboxed-Event"] = "email_received"
    request["X-Inboxed-Delivery"] = delivery_id
    request["X-Inboxed-Timestamp"] = timestamp.to_s
    request["X-Inboxed-Signature"] = signature
    request.body = body

    response = http.request(request)
    {
      success: response.code.to_i.between?(200, 299),
      status: response.code.to_i,
      body: response.body
    }
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError => e
    {success: false, status: nil, body: e.message}
  end
end
