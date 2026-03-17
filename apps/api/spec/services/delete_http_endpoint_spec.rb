# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::Services::DeleteHttpEndpoint do
  subject(:service) { described_class.new }

  let!(:project) do
    ProjectRecord.create!(id: SecureRandom.uuid, name: "Test", slug: "test-delete-ep")
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

  it "destroys the endpoint" do
    expect {
      service.call(token: endpoint.token, project_id: project.id)
    }.to change(HttpEndpointRecord, :count).by(-1)
  end

  it "destroys associated requests" do
    HttpRequestRecord.create!(
      http_endpoint_id: endpoint.id,
      method: "POST",
      headers: {},
      size_bytes: 0,
      received_at: Time.current
    )

    expect {
      service.call(token: endpoint.token, project_id: project.id)
    }.to change(HttpRequestRecord, :count).by(-1)
  end

  it "publishes an HttpEndpointDeleted event" do
    service.call(token: endpoint.token, project_id: project.id)

    events = EventRecord.where(event_type: "Inboxed::Events::HttpEndpointDeleted")
    expect(events.count).to eq(1)
  end

  it "raises RecordNotFound for wrong project" do
    other_project = ProjectRecord.create!(id: SecureRandom.uuid, name: "Other", slug: "other-del")

    expect {
      service.call(token: endpoint.token, project_id: other_project.id)
    }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
