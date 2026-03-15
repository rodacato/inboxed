# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::Aggregates::InboxAggregate do
  let(:inbox_id) { SecureRandom.uuid }
  let(:project_id) { SecureRandom.uuid }
  let(:aggregate) { described_class.new(inbox_id) }

  before do
    aggregate.create(project_id: project_id, address: "test@example.com")
  end

  describe "#create" do
    it "sets project_id and address" do
      expect(aggregate.project_id).to eq(project_id)
      expect(aggregate.address).to eq("test@example.com")
    end

    it "emits InboxCreated event" do
      events = aggregate.pending_events
      expect(events.size).to eq(1)
      expect(events.first).to be_a(Inboxed::Events::InboxCreated)
    end
  end

  describe "#receive_email" do
    it "increments email_count" do
      aggregate.receive_email(
        id: SecureRandom.uuid,
        from: "sender@test.com",
        to: ["test@example.com"],
        subject: "Test",
        source_type: "relay",
        expires_at: 1.day.from_now
      )
      expect(aggregate.email_count).to eq(1)
    end

    it "emits EmailReceived event" do
      aggregate.clear_pending_events
      aggregate.receive_email(
        id: SecureRandom.uuid,
        from: "sender@test.com",
        to: ["test@example.com"],
        subject: "Test",
        source_type: "relay",
        expires_at: 1.day.from_now
      )
      expect(aggregate.pending_events.last).to be_a(Inboxed::Events::EmailReceived)
    end
  end

  describe "#delete_email" do
    it "decrements email_count" do
      email_id = SecureRandom.uuid
      aggregate.receive_email(
        id: email_id, from: "a@b.com", to: ["test@example.com"],
        subject: "X", source_type: "relay", expires_at: 1.day.from_now
      )
      aggregate.delete_email(email_id: email_id)
      expect(aggregate.email_count).to eq(0)
    end
  end

  describe "snapshot" do
    it "can snapshot and restore state" do
      aggregate.receive_email(
        id: SecureRandom.uuid, from: "a@b.com", to: ["test@example.com"],
        subject: "X", source_type: "relay", expires_at: 1.day.from_now
      )

      state = aggregate.snapshot_state
      restored = described_class.new(inbox_id)
      restored.restore_from_snapshot(state)

      expect(restored.project_id).to eq(project_id)
      expect(restored.address).to eq("test@example.com")
      expect(restored.email_count).to eq(1)
    end
  end
end
