# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::Services::PurgeHttpRequests do
  subject(:service) { described_class.new }

  let!(:project) do
    ProjectRecord.create!(id: SecureRandom.uuid, name: "Test", slug: "test-purge")
  end

  let!(:endpoint) do
    HttpEndpointRecord.create!(
      project_id: project.id,
      endpoint_type: "webhook",
      label: "test",
      allowed_methods: %w[POST],
      max_body_bytes: 262_144
    )
  end

  before do
    3.times do
      HttpRequestRecord.create!(
        http_endpoint_id: endpoint.id,
        method: "POST",
        headers: {},
        size_bytes: 0,
        received_at: Time.current
      )
    end
    HttpEndpointRecord.where(id: endpoint.id).update_all(request_count: 3)
  end

  it "deletes all requests for the endpoint" do
    expect {
      service.call(token: endpoint.token, project_id: project.id)
    }.to change(HttpRequestRecord, :count).by(-3)
  end

  it "resets request_count to 0" do
    service.call(token: endpoint.token, project_id: project.id)
    expect(endpoint.reload.request_count).to eq(0)
  end

  it "returns the deleted count" do
    result = service.call(token: endpoint.token, project_id: project.id)
    expect(result).to eq(3)
  end
end
