# frozen_string_literal: true

module Hooks
  class InboundController < ApplicationController
    skip_before_action :verify_authenticity_token, raise: false

    before_action :authenticate_webhook_secret!
    before_action :validate_envelope_headers!

    # POST /hooks/inbound
    def create
      result = Inboxed::Services::ReceiveInboundEmail.new.call(
        envelope_to: request.headers["X-Envelope-To"],
        envelope_from: request.headers["X-Envelope-From"] || "unknown@unknown",
        raw_source: request.body.read
      )

      render json: {data: result}, status: :accepted
    end

    private

    def authenticate_webhook_secret!
      secret = ENV["INBOUND_WEBHOOK_SECRET"]
      return render json: {error: "inbound webhook not configured"}, status: :service_unavailable unless secret.present?

      token = request.headers["Authorization"]&.delete_prefix("Bearer ")&.strip

      unless token.present? && ActiveSupport::SecurityUtils.secure_compare(token, secret)
        render json: {error: "unauthorized"}, status: :unauthorized
      end
    end

    def validate_envelope_headers!
      unless request.headers["X-Envelope-To"].present?
        render json: {error: "missing X-Envelope-To header"}, status: :unprocessable_entity
      end
    end
  end
end
