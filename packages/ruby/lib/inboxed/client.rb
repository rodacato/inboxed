# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module Inboxed
  class Client
    def initialize(api_url:, api_key:)
      @base_url = api_url.chomp("/")
      @api_key = api_key
    end

    # ── Core operations ────────────────────────────────────────

    def wait_for_email(inbox, subject: nil, timeout: 30)
      inbox_record = resolve_inbox(inbox)
      subject_pattern = subject.is_a?(Regexp) ? subject.source : subject

      body = {inbox_id: inbox_record["id"], timeout: timeout}
      body[:subject_pattern] = subject_pattern if subject_pattern

      uri = URI("#{@base_url}/api/v1/emails/wait")
      response = post_request(uri, body)

      if response.code == "408"
        raise TimeoutError, "No email arrived at #{inbox} within #{timeout} seconds."
      end

      assert_ok!(response)
      summary = JSON.parse(response.body)
      fetch_full_email(summary["id"])
    end

    def latest_email(inbox)
      inbox_record = resolve_inbox(inbox)
      data = get_request("/api/v1/inboxes/#{inbox_record["id"]}/emails?limit=1")
      emails = data["data"]
      return nil if emails.empty?

      fetch_full_email(emails.first["id"])
    end

    def list_emails(inbox, limit: 10)
      inbox_record = resolve_inbox(inbox)
      data = get_request("/api/v1/inboxes/#{inbox_record["id"]}/emails?limit=#{limit}")
      data["data"].map { |e| fetch_full_email(e["id"]) }
    end

    def search_emails(query, limit: 10)
      data = get_request("/api/v1/search?q=#{URI.encode_uri_component(query)}&limit=#{limit}")
      data["data"].map { |e| fetch_full_email(e["id"]) }
    end

    def delete_inbox(inbox)
      inbox_record = resolve_inbox(inbox)
      uri = URI("#{@base_url}/api/v1/inboxes/#{inbox_record["id"]}")
      request = Net::HTTP::Delete.new(uri)
      apply_headers(request)
      response = execute(uri, request)
      assert_ok!(response)
      nil
    end

    # ── Extraction ─────────────────────────────────────────────

    def extract_code(inbox, pattern: nil)
      email = latest_email(inbox)
      return nil unless email

      Extract.code(email.body_text, email.body_html, pattern: pattern)
    end

    def extract_link(inbox, pattern: nil)
      email = latest_email(inbox)
      return nil unless email

      urls = Extract.link(email.body_text, email.body_html)
      if pattern
        regex = pattern.is_a?(Regexp) ? pattern : Regexp.new(pattern, Regexp::IGNORECASE)
        urls = urls.select { |url| url.match?(regex) }
      end
      urls.first
    end

    def extract_value(inbox, label:, pattern: nil)
      email = latest_email(inbox)
      return nil unless email

      Extract.value(email.body_text, email.body_html, label: label, pattern: pattern)
    end

    private

    def resolve_inbox(address)
      data = get_request("/api/v1/inboxes?address=#{URI.encode_uri_component(address)}")
      inboxes = data["data"]
      raise NotFoundError, "Inbox not found: #{address}" if inboxes.empty?

      inboxes.first
    end

    def fetch_full_email(id)
      data = get_request("/api/v1/emails/#{id}")
      Email.new(data)
    end

    def get_request(path)
      uri = URI("#{@base_url}#{path}")
      request = Net::HTTP::Get.new(uri)
      apply_headers(request)
      response = execute(uri, request)
      assert_ok!(response)
      JSON.parse(response.body)
    end

    def post_request(uri, body)
      request = Net::HTTP::Post.new(uri)
      apply_headers(request)
      request.body = JSON.generate(body)
      execute(uri, request)
    end

    def apply_headers(request)
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{@api_key}"
    end

    def execute(uri, request)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end
    end

    def assert_ok!(response)
      case response.code
      when "200", "201", "204"
        # ok
      when "401", "403"
        raise AuthError, "Authentication failed. Check your API key."
      when "404"
        raise NotFoundError, "Resource not found."
      else
        raise Error, "Inboxed API error: #{response.code} #{response.message}"
      end
    end
  end
end
