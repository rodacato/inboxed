# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::Services::ReceiveEmail do
  subject(:service) { described_class.new }

  let!(:project) do
    ProjectRecord.create!(
      id: SecureRandom.uuid,
      name: "Test Project",
      slug: "test",
      default_ttl_hours: 24
    )
  end

  let(:raw_email) do
    <<~EMAIL
      From: sender@app.test
      To: user@example.com
      Subject: Your verification code: 1234

      Your code is 1234. It expires in 10 minutes.
    EMAIL
  end

  it "creates an inbox for the recipient" do
    expect {
      service.call(
        project_id: project.id,
        raw_source: raw_email,
        envelope_to: ["user@example.com"],
        source_type: "relay"
      )
    }.to change(InboxRecord, :count).by(1)

    inbox = InboxRecord.last
    expect(inbox.address).to eq("user@example.com")
    expect(inbox.project_id).to eq(project.id)
  end

  it "persists the email" do
    service.call(
      project_id: project.id,
      raw_source: raw_email,
      envelope_to: ["user@example.com"],
      source_type: "relay"
    )

    email = EmailRecord.last
    expect(email.from_address).to eq("sender@app.test")
    expect(email.subject).to eq("Your verification code: 1234")
    expect(email.body_text).to include("Your code is 1234")
    expect(email.source_type).to eq("relay")
    expect(email.expires_at).to be_within(1.minute).of(24.hours.from_now)
  end

  it "publishes an EmailReceived event" do
    service.call(
      project_id: project.id,
      raw_source: raw_email,
      envelope_to: ["user@example.com"],
      source_type: "relay"
    )

    events = EventRecord.where(event_type: "Inboxed::Events::EmailReceived")
    expect(events.count).to eq(1)
  end

  it "increments inbox email_count" do
    service.call(
      project_id: project.id,
      raw_source: raw_email,
      envelope_to: ["user@example.com"],
      source_type: "relay"
    )

    expect(InboxRecord.last.email_count).to eq(1)
  end

  it "handles multiple recipients" do
    service.call(
      project_id: project.id,
      raw_source: raw_email,
      envelope_to: ["a@example.com", "b@example.com"],
      source_type: "relay"
    )

    expect(InboxRecord.count).to eq(2)
    expect(EmailRecord.count).to eq(2)
  end

  it "uses ENV TTL when project has no default" do
    project.update!(default_ttl_hours: nil)

    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("EMAIL_TTL_HOURS", 168).and_return("48")

    service.call(
      project_id: project.id,
      raw_source: raw_email,
      envelope_to: ["user@example.com"],
      source_type: "relay"
    )

    email = EmailRecord.last
    expect(email.expires_at).to be_within(1.minute).of(48.hours.from_now)
  end

  it "reuses existing inbox for same address" do
    2.times do
      service.call(
        project_id: project.id,
        raw_source: raw_email,
        envelope_to: ["user@example.com"],
        source_type: "relay"
      )
    end

    expect(InboxRecord.count).to eq(1)
    expect(EmailRecord.count).to eq(2)
    expect(InboxRecord.last.email_count).to eq(2)
  end
end
