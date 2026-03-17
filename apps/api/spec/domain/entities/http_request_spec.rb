# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::Entities::HttpRequest do
  def build(attrs = {})
    described_class.new({
      id: SecureRandom.uuid,
      http_endpoint_id: SecureRandom.uuid,
      method: "POST",
      headers: {},
      size_bytes: 0,
      received_at: Time.current
    }.merge(attrs))
  end

  describe "#json_body?" do
    it "returns true for application/json" do
      req = build(content_type: "application/json")
      expect(req.json_body?).to be true
    end

    it "returns false for other types" do
      req = build(content_type: "text/plain")
      expect(req.json_body?).to be false
    end

    it "returns falsey when nil" do
      req = build(content_type: nil)
      expect(req.json_body?).to be_falsey
    end
  end

  describe "#form_data?" do
    it "returns true for url-encoded" do
      req = build(content_type: "application/x-www-form-urlencoded")
      expect(req.form_data?).to be true
    end

    it "returns true for multipart" do
      req = build(content_type: "multipart/form-data; boundary=---abc")
      expect(req.form_data?).to be true
    end
  end

  describe "#parsed_json" do
    it "parses valid JSON body" do
      req = build(
        content_type: "application/json",
        body: '{"status":"paid","amount":1000}'
      )
      expect(req.parsed_json).to eq("status" => "paid", "amount" => 1000)
    end

    it "returns nil for invalid JSON" do
      req = build(content_type: "application/json", body: "not json")
      expect(req.parsed_json).to be_nil
    end

    it "returns nil when body is nil" do
      req = build(content_type: "application/json", body: nil)
      expect(req.parsed_json).to be_nil
    end
  end

  describe "#parsed_form_fields" do
    it "parses url-encoded body" do
      req = build(
        content_type: "application/x-www-form-urlencoded",
        body: "name=John+Doe&email=john%40test.com&newsletter=on"
      )
      fields = req.parsed_form_fields
      expect(fields["name"]).to eq("John Doe")
      expect(fields["email"]).to eq("john@test.com")
      expect(fields["newsletter"]).to eq("on")
    end

    it "returns nil for non-form content type" do
      req = build(content_type: "application/json", body: "name=test")
      expect(req.parsed_form_fields).to be_nil
    end
  end
end
