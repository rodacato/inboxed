# frozen_string_literal: true

require "midi-smtp-server"

module Inboxed
  class SmtpServer < MidiSmtpServer::Smtpd
    def initialize
      super(
        ports: ENV.fetch("SMTP_PORTS", "2525"),
        hosts: ENV.fetch("SMTP_HOST", "0.0.0.0"),
        max_processings: ENV.fetch("SMTP_MAX_CONNECTIONS", 4).to_i,
        auth_mode: :AUTH_REQUIRED,
        tls_mode: tls_mode,
        tls_cert_path: ENV["SMTP_TLS_CERT"],
        tls_key_path: ENV["SMTP_TLS_KEY"]
      )
    end

    # Validate API key on AUTH
    def on_auth_event(_ctx, _authorization_id, _authentication_id, authentication)
      api_key = authenticate_api_key(authentication)
      unless api_key
        log_json(event: "auth_failed")
        raise MidiSmtpServer::Smtpd535Exception
      end
      log_json(event: "auth_success", project_id: api_key.project_id)
      api_key.id
    end

    # Accept MAIL FROM as-is
    def on_mail_from_event(_ctx, mail_from_data)
      mail_from_data
    end

    # Accept any RCPT TO (catch-all)
    def on_rcpt_to_event(_ctx, rcpt_to_data)
      rcpt_to_data
    end

    # Process complete message — enqueue for async processing
    def on_message_data_event(ctx)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      auth_id = ctx[:server][:authorization_id]
      api_key = ApiKeyRecord.find_by(id: auth_id)
      return unless api_key

      envelope_from = ctx[:envelope][:from]
      envelope_to = ctx[:envelope][:to]
      raw_source = ctx[:message][:data]

      ReceiveEmailJob.perform_later(
        project_id: api_key.project_id,
        api_key_id: api_key.id,
        envelope_from: envelope_from,
        envelope_to: envelope_to,
        raw_source: raw_source,
        source_type: "relay"
      )

      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round(1)
      log_json(
        event: "email_received",
        from: envelope_from,
        to: Array(envelope_to).join(", "),
        size_bytes: raw_source.bytesize,
        duration_ms: duration_ms
      )
    end

    def self.start
      server = new
      server.start
      server.send(:log_json,
        event: "server_started",
        host: ENV.fetch("SMTP_HOST", "0.0.0.0"),
        port: ENV.fetch("SMTP_PORTS", "2525"))

      trap("INT") { server.stop }
      trap("TERM") { server.stop }

      server.join
    end

    private

    def log_json(**fields)
      payload = {service: "smtp", timestamp: Time.now.utc.iso8601}.merge(fields)
      Rails.logger.info(payload.to_json)
    end

    def tls_mode
      if ENV["SMTP_TLS_CERT"].present?
        :TLS_OPTIONAL
      else
        :TLS_FORBIDDEN
      end
    end

    def authenticate_api_key(token)
      return nil if token.blank?
      prefix = token[0, 8]
      candidates = ApiKeyRecord.where(token_prefix: prefix)
      candidates.find { |k| BCrypt::Password.new(k.token_digest) == token }
    end
  end
end
