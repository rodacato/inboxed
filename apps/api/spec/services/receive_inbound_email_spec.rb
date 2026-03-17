# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::Services::ReceiveInboundEmail do
  include ActiveJob::TestHelper

  subject(:service) { described_class.new }

  before { ActiveJob::Base.queue_adapter = :test }

  let!(:project_a) do
    ProjectRecord.create!(
      id: SecureRandom.uuid,
      name: "Project A",
      slug: "project-a",
      default_ttl_hours: 24
    )
  end

  let!(:project_b) do
    ProjectRecord.create!(
      id: SecureRandom.uuid,
      name: "Project B",
      slug: "project-b",
      default_ttl_hours: 24
    )
  end

  let(:shared_address) { "test@mail.notdefined.dev" }

  let(:raw_email) do
    <<~EMAIL
      From: sender@gmail.com
      To: #{shared_address}
      Subject: Your verification code
      Date: #{Time.current.rfc2822}
      Message-ID: <test123@gmail.com>

      Your verification code is 847291.
    EMAIL
  end

  before do
    # Create inboxes in both projects for the same address
    InboxRecord.create!(id: SecureRandom.uuid, project: project_a, address: shared_address, email_count: 0)
    InboxRecord.create!(id: SecureRandom.uuid, project: project_b, address: shared_address, email_count: 0)
  end

  describe "fan-out delivery" do
    context "when feature is enabled" do
      before do
        allow(Inboxed::Features).to receive(:enabled?).with(:inbound_email).and_return(true)
      end

      it "enqueues a job for each matching inbox" do
        expect {
          service.call(envelope_to: shared_address, envelope_from: "sender@gmail.com", raw_source: raw_email)
        }.to have_enqueued_job(ReceiveEmailJob).exactly(2).times
      end

      it "returns delivered count" do
        result = service.call(envelope_to: shared_address, envelope_from: "sender@gmail.com", raw_source: raw_email)

        expect(result[:delivered_to]).to eq(2)
        expect(result[:redacted]).to eq(0)
      end

      it "enqueues jobs with source_type inbound" do
        service.call(envelope_to: shared_address, envelope_from: "sender@gmail.com", raw_source: raw_email)

        enqueued = queue_adapter.enqueued_jobs.select { |j| j["job_class"] == "ReceiveEmailJob" }
        enqueued.each do |job|
          args = job["arguments"].first
          expect(args["source_type"]).to eq("inbound")
        end
      end
    end

    context "when feature is disabled" do
      before do
        allow(Inboxed::Features).to receive(:enabled?).with(:inbound_email).and_return(false)
      end

      it "enqueues jobs with redacted source" do
        service.call(envelope_to: shared_address, envelope_from: "sender@gmail.com", raw_source: raw_email)

        enqueued = queue_adapter.enqueued_jobs.select { |j| j["job_class"] == "ReceiveEmailJob" }
        enqueued.each do |job|
          args = job["arguments"].first
          expect(args["source_type"]).to eq("inbound_redacted")
          expect(args["raw_source"]).to include("[Inboxed]")
          expect(args["raw_source"]).to include("inbound email is not enabled")
          expect(args["raw_source"]).not_to include("847291")
        end
      end

      it "returns redacted count" do
        result = service.call(envelope_to: shared_address, envelope_from: "sender@gmail.com", raw_source: raw_email)

        expect(result[:delivered_to]).to eq(0)
        expect(result[:redacted]).to eq(2)
      end

      it "preserves sender and subject in redacted email" do
        service.call(envelope_to: shared_address, envelope_from: "sender@gmail.com", raw_source: raw_email)

        enqueued = queue_adapter.enqueued_jobs.select { |j| j["job_class"] == "ReceiveEmailJob" }
        redacted_source = enqueued.first["arguments"].first["raw_source"]
        parsed = Mail.new(redacted_source)

        expect(parsed.from).to include("sender@gmail.com")
        expect(parsed.subject).to eq("Your verification code")
      end
    end
  end

  describe "no matching inboxes" do
    it "returns zero counts when no inbox matches" do
      result = service.call(
        envelope_to: "nonexistent@mail.notdefined.dev",
        envelope_from: "sender@gmail.com",
        raw_source: raw_email
      )

      expect(result[:delivered_to]).to eq(0)
      expect(result[:redacted]).to eq(0)
    end

    it "does not create any inboxes" do
      expect {
        service.call(
          envelope_to: "nonexistent@mail.notdefined.dev",
          envelope_from: "sender@gmail.com",
          raw_source: raw_email
        )
      }.not_to change(InboxRecord, :count)
    end
  end

  describe "fan-out limit" do
    before do
      allow(Inboxed::Features).to receive(:enabled?).with(:inbound_email).and_return(true)

      # Create 12 more inboxes (14 total, above MAX_FAN_OUT of 10)
      12.times do |i|
        project = ProjectRecord.create!(
          id: SecureRandom.uuid,
          name: "Project Extra #{i}",
          slug: "project-extra-#{i}",
          default_ttl_hours: 24
        )
        InboxRecord.create!(id: SecureRandom.uuid, project: project, address: shared_address, email_count: 0)
      end
    end

    it "limits fan-out to MAX_FAN_OUT" do
      result = service.call(envelope_to: shared_address, envelope_from: "sender@gmail.com", raw_source: raw_email)

      expect(result[:delivered_to]).to be <= described_class::MAX_FAN_OUT
    end
  end
end
