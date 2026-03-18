# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin Tenant Isolation", type: :request do
  # Org A — the authenticated user's org
  let!(:user_and_org_a) { create_authenticated_user(email: "admin-a@test.dev") }
  let!(:user_a) { user_and_org_a[0] }
  let!(:org_a) { user_and_org_a[1] }
  let!(:project_a) { ProjectRecord.create!(name: "Project A", slug: "proj-a-#{SecureRandom.hex(4)}", organization: org_a) }
  let!(:inbox_a) { InboxRecord.create!(project: project_a, address: "a@test.dev") }
  let!(:email_a) do
    EmailRecord.create!(
      inbox: inbox_a,
      from_address: "sender@example.com",
      to_addresses: ["a@test.dev"],
      subject: "Org A Email",
      body_text: "Secret A",
      raw_source: "From: sender@example.com\r\nSubject: Org A\r\n\r\nSecret A",
      raw_headers: {"From" => "sender@example.com"},
      received_at: Time.current,
      expires_at: 7.days.from_now,
      source_type: "relay"
    )
  end
  let!(:attachment_a) do
    AttachmentRecord.create!(
      email: email_a,
      filename: "secret.pdf",
      content_type: "application/pdf",
      content: "secret-content-a",
      size_bytes: 16,
      inline: false
    )
  end
  let!(:api_key_a) do
    result = Inboxed::Services::IssueApiKey.new.call(project_id: project_a.id, label: "Key A")
    ApiKeyRecord.find(result[:id])
  end

  # Org B — a different org the user should NOT be able to access
  let!(:org_b) { OrganizationRecord.create!(name: "Org B", slug: "org-b-#{SecureRandom.hex(4)}") }
  let!(:project_b) { ProjectRecord.create!(name: "Project B", slug: "proj-b-#{SecureRandom.hex(4)}", organization: org_b) }
  let!(:inbox_b) { InboxRecord.create!(project: project_b, address: "b@test.dev") }
  let!(:email_b) do
    EmailRecord.create!(
      inbox: inbox_b,
      from_address: "sender@example.com",
      to_addresses: ["b@test.dev"],
      subject: "Org B Email",
      body_text: "Secret B",
      raw_source: "From: sender@example.com\r\nSubject: Org B\r\n\r\nSecret B",
      raw_headers: {"From" => "sender@example.com"},
      received_at: Time.current,
      expires_at: 7.days.from_now,
      source_type: "relay"
    )
  end
  let!(:attachment_b) do
    AttachmentRecord.create!(
      email: email_b,
      filename: "secret-b.pdf",
      content_type: "application/pdf",
      content: "secret-content-b",
      size_bytes: 16,
      inline: false
    )
  end
  let!(:api_key_b) do
    result = Inboxed::Services::IssueApiKey.new.call(project_id: project_b.id, label: "Key B")
    ApiKeyRecord.find(result[:id])
  end

  before { sign_in(user_a) }

  # --- Emails ---

  describe "email tenant isolation" do
    it "cannot view another org's email" do
      get "/admin/emails/#{email_b.id}"
      expect(response).to have_http_status(:not_found)
    end

    it "cannot view another org's email raw source" do
      get "/admin/emails/#{email_b.id}/raw"
      expect(response).to have_http_status(:not_found)
    end

    it "cannot delete another org's email" do
      delete "/admin/emails/#{email_b.id}"
      expect(response).to have_http_status(:not_found)
      expect(EmailRecord.find_by(id: email_b.id)).to be_present
    end

    it "can view own org's email" do
      get "/admin/emails/#{email_a.id}"
      expect(response).to have_http_status(:ok)
    end
  end

  # --- Attachments ---

  describe "attachment tenant isolation" do
    it "cannot list another org's email attachments" do
      get "/admin/emails/#{email_b.id}/attachments"
      expect(response).to have_http_status(:not_found)
    end

    it "cannot download another org's attachment" do
      get "/admin/attachments/#{attachment_b.id}/download"
      expect(response).to have_http_status(:not_found)
    end

    it "can download own org's attachment" do
      get "/admin/attachments/#{attachment_a.id}/download"
      expect(response).to have_http_status(:ok)
    end
  end

  # --- API Keys ---

  describe "api key tenant isolation" do
    it "cannot update another org's API key" do
      patch "/admin/api_keys/#{api_key_b.id}", params: {api_key: {label: "Hacked"}}, as: :json
      expect(response).to have_http_status(:not_found)
      expect(api_key_b.reload.label).to eq("Key B")
    end

    it "cannot delete another org's API key" do
      delete "/admin/api_keys/#{api_key_b.id}"
      expect(response).to have_http_status(:not_found)
      expect(ApiKeyRecord.find_by(id: api_key_b.id)).to be_present
    end

    it "can update own org's API key" do
      patch "/admin/api_keys/#{api_key_a.id}", params: {api_key: {label: "Renamed"}}, as: :json
      expect(response).to have_http_status(:ok)
      expect(api_key_a.reload.label).to eq("Renamed")
    end
  end

  # --- Projects ---

  describe "project tenant isolation" do
    it "cannot view another org's project" do
      get "/admin/projects/#{project_b.id}"
      expect(response).to have_http_status(:not_found)
    end

    it "cannot list another org's project emails" do
      get "/admin/projects/#{project_b.id}/emails"
      expect(response).to have_http_status(:not_found)
    end

    it "cannot list another org's project inboxes" do
      get "/admin/projects/#{project_b.id}/inboxes"
      expect(response).to have_http_status(:not_found)
    end

    it "cannot list another org's project endpoints" do
      get "/admin/projects/#{project_b.id}/endpoints"
      expect(response).to have_http_status(:not_found)
    end

    it "cannot list another org's project API keys" do
      get "/admin/projects/#{project_b.id}/api_keys"
      expect(response).to have_http_status(:not_found)
    end
  end

  # --- Search ---

  describe "search tenant isolation" do
    it "only returns results from own org" do
      get "/admin/search", params: {q: "Secret"}
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      subjects = body["emails"].map { |e| e["subject"] }
      expect(subjects).to include("Org A Email")
      expect(subjects).not_to include("Org B Email")
    end
  end
end
