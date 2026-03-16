# frozen_string_literal: true

class HooksController < ApplicationController
  before_action :find_endpoint
  before_action :check_method_allowed
  before_action :check_ip_allowed
  before_action :check_body_size

  def catch
    request_data = build_captured_request

    result = Inboxed::Services::CaptureHttpRequest.new.call(
      endpoint: @endpoint,
      request_data: request_data
    )

    respond_to_endpoint_type(result)
  end

  private

  def find_endpoint
    @endpoint = HttpEndpointRecord.find_by(token: params[:token])
    head :not_found unless @endpoint
  end

  def check_method_allowed
    return unless @endpoint
    unless @endpoint.allowed_methods.include?(request.method)
      head :method_not_allowed
    end
  end

  def check_ip_allowed
    return unless @endpoint
    if @endpoint.allowed_ips.present? && !@endpoint.allowed_ips.include?(request.remote_ip)
      head :forbidden
    end
  end

  def check_body_size
    return unless @endpoint
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
      next unless key.is_a?(String)
      next unless key.start_with?("HTTP_") || %w[CONTENT_TYPE CONTENT_LENGTH].include?(key)
      normalized = key.sub(/^HTTP_/, "").tr("_", "-").downcase
      hash[normalized] = value
    end
  end

  def respond_to_endpoint_type(result)
    case @endpoint.endpoint_type
    when "form"
      respond_as_form(result)
    when "heartbeat"
      render json: {ok: true, status: result[:heartbeat_status]}
    else
      render json: {ok: true, id: result[:request_id]}
    end
  end

  def respond_as_form(result)
    case @endpoint.response_mode
    when "redirect"
      url = @endpoint.response_redirect_url.to_s
      if safe_redirect_url?(url)
        redirect_to url, allow_other_host: true
      else
        head :bad_request
      end
    when "html"
      html = @endpoint.response_html.presence || default_thank_you_html
      render html: sanitize_response_html(html).html_safe
    else
      render json: {ok: true, id: result[:request_id]}
    end
  end

  def safe_redirect_url?(url)
    return false if url.blank?
    return true if url.start_with?("/") && !url.start_with?("//")

    uri = URI.parse(url)
    uri.scheme.in?(%w[http https]) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end

  def sanitize_response_html(html)
    Rails::HTML5::SafeListSanitizer.new.sanitize(
      html,
      tags: %w[html head title body h1 h2 h3 h4 h5 h6 p a br hr div span ul ol li
               strong em b i u table thead tbody tfoot tr td th img form input
               label button select option textarea meta link style],
      attributes: %w[href src alt title class id style name type value placeholder
                     action method charset content rel media]
    )
  end

  def default_thank_you_html
    <<~HTML
      <!DOCTYPE html>
      <html><head><title>Received</title></head>
      <body style="font-family:monospace;text-align:center;padding:4rem;">
        <h1>Form received</h1>
        <p>Captured by Inboxed</p>
      </body></html>
    HTML
  end
end
