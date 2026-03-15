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
      raise MidiSmtpServer::Smtpd535Exception unless api_key
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
      auth_id = ctx[:server][:authenticated]
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
    end

    def self.start
      server = new
      server.start
      Rails.logger.info("[SMTP] Server listening on #{ENV.fetch("SMTP_HOST", "0.0.0.0")}:#{ENV.fetch("SMTP_PORTS", "2525")}")

      trap("INT") { server.stop }
      trap("TERM") { server.stop }

      server.join
    end

    private

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
