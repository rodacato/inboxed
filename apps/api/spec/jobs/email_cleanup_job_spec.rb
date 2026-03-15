# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmailCleanupJob do
  let!(:project) do
    ProjectRecord.create!(
      id: SecureRandom.uuid,
      name: "Test", slug: "test-cleanup"
    )
  end

  let!(:inbox) do
    InboxRecord.create!(
      id: SecureRandom.uuid,
      project: project,
      address: "cleanup@test.com",
      email_count: 2
    )
  end

  let!(:expired_email) do
    EmailRecord.create!(
      id: SecureRandom.uuid,
      inbox: inbox,
      from_address: "a@b.com",
      subject: "Old",
      raw_source: "From: a@b.com\nSubject: Old\n\nold",
      source_type: "relay",
      received_at: 8.days.ago,
      expires_at: 1.day.ago
    )
  end

  let!(:valid_email) do
    EmailRecord.create!(
      id: SecureRandom.uuid,
      inbox: inbox,
      from_address: "a@b.com",
      subject: "New",
      raw_source: "From: a@b.com\nSubject: New\n\nnew",
      source_type: "relay",
      received_at: 1.hour.ago,
      expires_at: 6.days.from_now
    )
  end

  it "deletes expired emails" do
    expect { described_class.perform_now }
      .to change(EmailRecord, :count).by(-1)

    expect(EmailRecord.exists?(expired_email.id)).to be false
    expect(EmailRecord.exists?(valid_email.id)).to be true
  end

  it "updates inbox email_count" do
    described_class.perform_now
    expect(inbox.reload.email_count).to eq(1)
  end

  it "deletes attachments of expired emails" do
    AttachmentRecord.create!(
      id: SecureRandom.uuid,
      email: expired_email,
      filename: "old.pdf",
      content_type: "application/pdf",
      size_bytes: 100,
      content: "data"
    )

    expect { described_class.perform_now }
      .to change(AttachmentRecord, :count).by(-1)
  end
end
