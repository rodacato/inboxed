# frozen_string_literal: true

require_relative "inboxed/errors"
require_relative "inboxed/email"
require_relative "inboxed/configuration"
require_relative "inboxed/extract"
require_relative "inboxed/client"

module Inboxed
  class << self
    def configure
      yield(configuration)
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    # ── Core operations (delegate to client) ──────────────────

    def wait_for_email(inbox, subject: nil, timeout: 30)
      client.wait_for_email(inbox, subject: subject, timeout: timeout)
    end

    def latest_email(inbox)
      client.latest_email(inbox)
    end

    def list_emails(inbox, limit: 10)
      client.list_emails(inbox, limit: limit)
    end

    def search_emails(query, limit: 10)
      client.search_emails(query, limit: limit)
    end

    def delete_inbox(inbox)
      client.delete_inbox(inbox)
    end

    # ── Extraction ────────────────────────────────────────────

    def extract_code(inbox, pattern: nil)
      client.extract_code(inbox, pattern: pattern)
    end

    def extract_link(inbox, pattern: nil)
      client.extract_link(inbox, pattern: pattern)
    end

    def extract_value(inbox, label:, pattern: nil)
      client.extract_value(inbox, label: label, pattern: pattern)
    end

    private

    def client
      @client ||= Client.new(
        api_url: configuration.api_url,
        api_key: configuration.api_key
      )
    end
  end
end
