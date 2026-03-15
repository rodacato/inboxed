# frozen_string_literal: true

module Api
  module V1
    class AttachmentsController < BaseController
      def index
        email = EmailRecord
          .joins(:inbox)
          .where(inboxes: {project_id: @current_project.id})
          .find(params[:email_id])

        attachments = AttachmentRecord.where(email_id: email.id)

        render json: {
          attachments: attachments.map { |a| serialize_attachment(a) }
        }
      end

      def download
        attachment = AttachmentRecord
          .joins(email: :inbox)
          .where(inboxes: {project_id: @current_project.id})
          .find(params[:id])

        send_data attachment.content,
          type: attachment.content_type,
          disposition: "attachment; filename=\"#{attachment.filename}\"",
          filename: attachment.filename
      end

      private

      def serialize_attachment(att)
        {
          id: att.id,
          filename: att.filename,
          content_type: att.content_type,
          size_bytes: att.size_bytes,
          inline: att.inline,
          download_url: "/api/v1/attachments/#{att.id}/download"
        }
      end
    end
  end
end
