# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inboxed::Extract do
  describe ".code" do
    it "extracts a 6-digit code" do
      expect(described_class.code("Your code is 482910", nil)).to eq("482910")
    end

    it "extracts a 4-digit code" do
      expect(described_class.code("Code: 1234", nil)).to eq("1234")
    end

    it "extracts an 8-digit code" do
      expect(described_class.code("Use 12345678 to verify", nil)).to eq("12345678")
    end

    it "returns nil when no code found" do
      expect(described_class.code("No code here", nil)).to be_nil
    end

    it "returns last match" do
      expect(described_class.code("First 111 then 222333", nil)).to eq("222333")
    end

    it "supports custom pattern" do
      expect(described_class.code("Code: AXK-9281", nil, pattern: "[A-Z]{3}-\\d{4}")).to eq("AXK-9281")
    end

    it "falls back to HTML body" do
      expect(described_class.code(nil, "<p>Code: <b>482910</b></p>")).to eq("482910")
    end

    it "returns nil for empty input" do
      expect(described_class.code(nil, nil)).to be_nil
    end
  end

  describe ".link" do
    it "extracts URLs from plain text" do
      urls = described_class.link("Click https://app.com/verify?t=abc to verify", nil)
      expect(urls).to eq(["https://app.com/verify?t=abc"])
    end

    it "extracts URLs from HTML href when text is nil" do
      urls = described_class.link(nil, '<a href="https://app.com/reset">Reset</a>')
      expect(urls).to eq(["https://app.com/reset"])
    end

    it "returns empty array when no links" do
      expect(described_class.link("No links here", nil)).to eq([])
    end

    it "returns empty for nil inputs" do
      expect(described_class.link(nil, nil)).to eq([])
    end

    it "prefers body_text over body_html" do
      urls = described_class.link("Visit https://text.com", '<a href="https://html.com">x</a>')
      expect(urls).to eq(["https://text.com"])
    end
  end

  describe ".value" do
    it "extracts password" do
      expect(described_class.value("Temporary password: xK9#mP2!", nil, label: "password")).to eq("xK9#mP2!")
    end

    it "extracts username" do
      expect(described_class.value("Your username: user_8a7c3f", nil, label: "username")).to eq("user_8a7c3f")
    end

    it "extracts reference number" do
      expect(described_class.value("Reference #: ORD-99281", nil, label: "Reference")).to eq("ORD-99281")
    end

    it "returns nil when not found" do
      expect(described_class.value("Welcome to our app!", nil, label: "password")).to be_nil
    end

    it "is case-insensitive" do
      expect(described_class.value("PASSWORD: secret123", nil, label: "password")).to eq("secret123")
    end

    it "supports custom pattern" do
      expect(described_class.value("Tracking: 1Z999AA1", nil, label: "Tracking", pattern: "[A-Z0-9]+")).to eq("1Z999AA1")
    end

    it "returns nil for empty input" do
      expect(described_class.value(nil, nil, label: "password")).to be_nil
    end
  end

  describe ".strip_html" do
    it "removes tags" do
      expect(described_class.strip_html("<p>Hello <b>World</b></p>")).to eq("Hello World")
    end

    it "converts br to newlines" do
      expect(described_class.strip_html("A<br>B<br/>C")).to eq("A\nB\nC")
    end

    it "decodes entities" do
      expect(described_class.strip_html("&amp; &lt; &gt;")).to eq("& < >")
    end
  end
end
