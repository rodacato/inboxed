# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::Types do
  describe "Email" do
    it "accepts valid emails" do
      expect(described_class::Email["user@example.com"]).to eq("user@example.com")
    end

    it "rejects invalid emails" do
      expect { described_class::Email["not-an-email"] }.to raise_error(Dry::Types::ConstraintError)
    end
  end

  describe "UUID" do
    it "accepts valid UUIDs" do
      uuid = SecureRandom.uuid
      expect(described_class::UUID[uuid]).to eq(uuid)
    end

    it "rejects invalid UUIDs" do
      expect { described_class::UUID["not-a-uuid"] }.to raise_error(Dry::Types::ConstraintError)
    end
  end

  describe "StreamName" do
    it "accepts valid stream names" do
      expect(described_class::StreamName["Message-#{SecureRandom.uuid}"]).to be_a(String)
    end

    it "rejects invalid stream names" do
      expect { described_class::StreamName["bad"] }.to raise_error(Dry::Types::ConstraintError)
    end
  end
end
