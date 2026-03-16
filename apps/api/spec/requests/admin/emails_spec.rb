# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Emails", type: :request do
  let!(:user_and_org) { create_authenticated_user }
  let!(:user) { user_and_org[0] }
  let!(:org) { user_and_org[1] }
  before { sign_in(user) }

  let!(:project) { ProjectRecord.create!(name: "Test Project", slug: "test-project", organization: org) }
  let!(:inbox) { InboxRecord.create!(project: project, address: "emails@test.dev") }

  def create_email(attrs = {})
    EmailRecord.create!({
      inbox: inbox,
      from_address: "sender@example.com",
      to_addresses: ["emails@test.dev"],
      subject: "Test Email",
      body_text: "Hello world",
      body_html: "<p>Hello world</p>",
      raw_source: "From: sender@example.com\r\nSubject: Test\r\n\r\nHello",
      raw_headers: {"From" => "sender@example.com"},
      received_at: Time.current,
      expires_at: 7.days.from_now,
      source_type: "relay"
    }.merge(attrs))
  end

  describe "GET /admin/projects/:pid/inboxes/:iid/emails" do
    it "returns 401 without session" do
      reset!
      get "/admin/projects/#{project.id}/inboxes/#{inbox.id}/emails"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns paginated email list" do
      3.times { |i| create_email(subject: "Email #{i}") }

      get "/admin/projects/#{project.id}/inboxes/#{inbox.id}/emails",
        params: {limit: 2}

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["emails"].size).to eq(2)
      expect(body["pagination"]["has_more"]).to be true
      expect(body["pagination"]["total_count"]).to eq(3)
    end
  end

  describe "GET /admin/emails/:id" do
    it "returns email detail with attachments" do
      email = create_email
      AttachmentRecord.create!(
        email: email,
        filename: "test.pdf",
        content_type: "application/pdf",
        content: "fake-pdf-content",
        size_bytes: 17,
        inline: false
      )

      get "/admin/emails/#{email.id}"
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["email"]["id"]).to eq(email.id)
      expect(body["email"]["subject"]).to eq("Test Email")
      expect(body["email"]["attachments"].size).to eq(1)
      expect(body["email"]["attachments"][0]["download_url"]).to start_with("/admin/")
    end

    it "returns 404 for non-existent email" do
      get "/admin/emails/00000000-0000-0000-0000-000000000000"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /admin/emails/:id/raw" do
    it "returns raw MIME source" do
      email = create_email(raw_source: "From: test@example.com\r\nSubject: Raw\r\n\r\nBody")

      get "/admin/emails/#{email.id}/raw"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("From: test@example.com")
    end
  end

  describe "DELETE /admin/emails/:id" do
    it "deletes the email" do
      email = create_email

      delete "/admin/emails/#{email.id}"
      expect(response).to have_http_status(:no_content)
      expect(EmailRecord.find_by(id: email.id)).to be_nil
    end
  end

  describe "DELETE /admin/projects/:pid/inboxes/:iid/emails (purge)" do
    it "purges all emails in inbox" do
      3.times { create_email }

      delete "/admin/projects/#{project.id}/inboxes/#{inbox.id}/emails"
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["deleted_count"]).to eq(3)
      expect(EmailRecord.where(inbox_id: inbox.id).count).to eq(0)
    end
  end
end
