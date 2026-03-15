# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::Webhooks::Signer do
  let(:secret) { "whsec_#{SecureRandom.hex(32)}" }
  let(:timestamp) { Time.current.to_i }
  let(:body) { '{"event":"email_received","data":{}}' }

  describe ".sign" do
    it "returns a sha256 prefixed HMAC signature" do
      signature = described_class.sign(secret, timestamp, body)
      expect(signature).to start_with("sha256=")
      expect(signature.sub("sha256=", "")).to match(/\A[0-9a-f]{64}\z/)
    end

    it "produces consistent signatures for the same input" do
      sig1 = described_class.sign(secret, timestamp, body)
      sig2 = described_class.sign(secret, timestamp, body)
      expect(sig1).to eq(sig2)
    end

    it "produces different signatures for different secrets" do
      sig1 = described_class.sign("secret_a", timestamp, body)
      sig2 = described_class.sign("secret_b", timestamp, body)
      expect(sig1).not_to eq(sig2)
    end

    it "produces different signatures for different timestamps" do
      sig1 = described_class.sign(secret, 1000, body)
      sig2 = described_class.sign(secret, 2000, body)
      expect(sig1).not_to eq(sig2)
    end

    it "signs timestamp.body as the payload" do
      expected_payload = "#{timestamp}.#{body}"
      expected_digest = OpenSSL::HMAC.hexdigest("SHA256", secret, expected_payload)
      expect(described_class.sign(secret, timestamp, body)).to eq("sha256=#{expected_digest}")
    end
  end

  describe ".verify" do
    it "returns true for a valid signature" do
      signature = described_class.sign(secret, timestamp, body)
      expect(described_class.verify(secret, timestamp, body, signature)).to be true
    end

    it "returns false for an invalid signature" do
      expect(described_class.verify(secret, timestamp, body, "sha256=invalid")).to be false
    end

    it "returns false for a tampered body" do
      signature = described_class.sign(secret, timestamp, body)
      expect(described_class.verify(secret, timestamp, "tampered", signature)).to be false
    end

    it "returns false for a different timestamp (replay protection)" do
      signature = described_class.sign(secret, timestamp, body)
      expect(described_class.verify(secret, timestamp + 1, body, signature)).to be false
    end
  end
end
