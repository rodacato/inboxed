# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::ValueObjects::MessageBody do
  describe "#empty?" do
    it "returns true when both html and text are nil" do
      body = described_class.new
      expect(body).to be_empty
    end

    it "returns false when html is present" do
      body = described_class.new(html: "<p>Hello</p>")
      expect(body).not_to be_empty
    end

    it "returns false when text is present" do
      body = described_class.new(text: "Hello")
      expect(body).not_to be_empty
    end
  end

  describe "#preview" do
    it "returns plain text truncated" do
      body = described_class.new(text: "Hello world this is a test")
      expect(body.preview(length: 11)).to eq("Hello world")
    end

    it "strips HTML tags when only html is available" do
      body = described_class.new(html: "<p>Hello <b>world</b></p>")
      expect(body.preview).to eq("Hello world")
    end

    it "prefers text over html" do
      body = described_class.new(text: "Plain", html: "<p>Rich</p>")
      expect(body.preview).to eq("Plain")
    end

    it "returns empty string when both are nil" do
      body = described_class.new
      expect(body.preview).to eq("")
    end
  end
end
