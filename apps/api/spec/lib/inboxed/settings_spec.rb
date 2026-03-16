# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::Settings do
  describe ".get and .set" do
    it "stores and retrieves a key-value pair" do
      described_class.set(:test_key, "test_value")

      expect(described_class.get(:test_key)).to eq("test_value")
    end

    it "returns nil for a missing key" do
      expect(described_class.get(:nonexistent_key)).to be_nil
    end

    it "overwrites existing values" do
      described_class.set(:overwrite_key, "first")
      described_class.set(:overwrite_key, "second")

      expect(described_class.get(:overwrite_key)).to eq("second")
    end
  end

  describe ".setup_completed?" do
    it "returns false when setup_completed_at is not set" do
      expect(described_class.setup_completed?).to be false
    end

    it "returns true when setup_completed_at is set" do
      described_class.set(:setup_completed_at, Time.current)

      expect(described_class.setup_completed?).to be true
    end
  end
end
