# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Attachments", type: :request do
  let!(:user_and_org) { create_authenticated_user }
  let!(:user) { user_and_org[0] }
  let!(:org) { user_and_org[1] }
  before { sign_in(user) }

  let!(:project) { ProjectRecord.create!(name: "Test Project", slug: "test-project", organization: org) }
  let!(:inbox) { InboxRecord.create!(project: project, address: "attach@test.dev") }
  let!(:email) do
    EmailRecord.create!(
      inbox: inbox,
      from_address: "sender@example.com",
      to_addresses: ["attach@test.dev"],
      subject: "With attachment",
      body_text: "See attached",
      raw_source: "raw",
      raw_headers: {},
      received_at: Time.current,
      expires_at: 7.days.from_now,
      source_type: "relay"
    )
  end
  let!(:attachment) do
    AttachmentRecord.create!(
      email: email,
      filename: "report.pdf",
      content_type: "application/pdf",
      content: "fake-pdf-binary",
      size_bytes: 15,
      inline: false
    )
  end

  describe "GET /admin/emails/:email_id/attachments" do
    it "returns 401 without session" do
      reset!
      get "/admin/emails/#{email.id}/attachments"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns attachment list" do
      get "/admin/emails/#{email.id}/attachments"
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["attachments"].size).to eq(1)
      expect(body["attachments"][0]["filename"]).to eq("report.pdf")
      expect(body["attachments"][0]["download_url"]).to start_with("/admin/")
    end
  end

  describe "GET /admin/attachments/:id/download" do
    it "returns the attachment binary" do
      get "/admin/attachments/#{attachment.id}/download"
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("fake-pdf-binary")
      expect(response.headers["Content-Type"]).to include("application/pdf")
    end
  end
end
