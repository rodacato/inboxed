# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReceiveEmailJob do
  let!(:project) do
    ProjectRecord.create!(
      id: SecureRandom.uuid,
      name: "Job Test",
      slug: "job-test",
      default_ttl_hours: 24
    )
  end

  let!(:api_key) do
    ApiKeyRecord.create!(
      id: SecureRandom.uuid,
      project: project,
      label: "test",
      token_prefix: "abcd1234",
      token_digest: BCrypt::Password.create("abcd1234" + "x" * 56)
    )
  end

  let(:raw_email) do
    <<~EMAIL
      From: noreply@cognito.amazonaws.com
      To: user@mail.notdefined.dev
      Subject: Your verification code is 482913

      Your Amazon Cognito verification code is: 482913
    EMAIL
  end

  let(:job_args) do
    {
      project_id: project.id,
      api_key_id: api_key.id,
      envelope_from: "noreply@cognito.amazonaws.com",
      envelope_to: ["user@mail.notdefined.dev"],
      raw_source: raw_email,
      source_type: "relay"
    }
  end

  it "delegates to ReceiveEmail service" do
    expect {
      described_class.perform_now(**job_args)
    }.to change(EmailRecord, :count).by(1)
      .and change(InboxRecord, :count).by(1)
  end

  it "updates api_key last_used_at" do
    expect {
      described_class.perform_now(**job_args)
    }.to change { api_key.reload.last_used_at }
  end

  it "creates inbox with correct address" do
    described_class.perform_now(**job_args)

    inbox = InboxRecord.last
    expect(inbox.address).to eq("user@mail.notdefined.dev")
    expect(inbox.project_id).to eq(project.id)
  end

  it "persists the email with parsed fields" do
    described_class.perform_now(**job_args)

    email = EmailRecord.last
    expect(email.from_address).to eq("noreply@cognito.amazonaws.com")
    expect(email.subject).to eq("Your verification code is 482913")
    expect(email.body_text).to include("482913")
    expect(email.source_type).to eq("relay")
  end

  it "handles multiple recipients" do
    described_class.perform_now(
      **job_args,
      envelope_to: ["a@test.com", "b@test.com"]
    )

    expect(InboxRecord.count).to eq(2)
    expect(EmailRecord.count).to eq(2)
  end
end
