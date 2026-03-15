# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::ValueObjects::EmailAddress do
  describe ".parse" do
    it "splits an email into local and domain" do
      addr = described_class.parse("user@example.com")
      expect(addr.local).to eq("user")
      expect(addr.domain).to eq("example.com")
    end

    it "handles subdomains" do
      addr = described_class.parse("test@mail.inboxed.dev")
      expect(addr.local).to eq("test")
      expect(addr.domain).to eq("mail.inboxed.dev")
    end
  end

  describe "#to_s" do
    it "reconstructs the full address" do
      addr = described_class.new(local: "user", domain: "example.com")
      expect(addr.to_s).to eq("user@example.com")
    end
  end

  it "is immutable" do
    addr = described_class.parse("user@example.com")
    expect { addr.instance_variable_set(:@local, "hacked") }.not_to change { addr.local }
  end
end
