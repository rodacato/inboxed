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
          attachments: attachments.map { |a| AttachmentSerializer.render(a) }
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
    end
  end
end
