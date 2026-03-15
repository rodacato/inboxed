# frozen_string_literal: true

module Inboxed
  module Webhooks
    class Signer
      def self.sign(secret, timestamp, body)
        payload = "#{timestamp}.#{body}"
        digest = OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
        "sha256=#{digest}"
      end

      def self.verify(secret, timestamp, body, signature)
        expected = sign(secret, timestamp, body)
        ActiveSupport::SecurityUtils.secure_compare(expected, signature)
      end
    end
  end
end
