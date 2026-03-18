# frozen_string_literal: true

module Admin
  class AttachmentsController < BaseController
    def index
      email = find_tenant_email
      attachments = AttachmentRecord.where(email_id: email.id)

      render json: {
        attachments: attachments.map { |a| serialize_attachment(a) }
      }
    end

    def download
      attachment = AttachmentRecord
        .joins(email: {inbox: :project})
        .where(projects: {id: tenant_project_ids})
        .find(params[:id])

      send_data attachment.content,
        type: attachment.content_type,
        disposition: "attachment; filename=\"#{attachment.filename}\"",
        filename: attachment.filename
    end

    private

    def find_tenant_email
      EmailRecord
        .joins(inbox: :project)
        .where(projects: {id: tenant_project_ids})
        .find(params[:email_id])
    end

    def serialize_attachment(att)
      {
        id: att.id,
        filename: att.filename,
        content_type: att.content_type,
        size_bytes: att.size_bytes,
        inline: att.inline,
        download_url: "/admin/attachments/#{att.id}/download"
      }
    end
  end
end
