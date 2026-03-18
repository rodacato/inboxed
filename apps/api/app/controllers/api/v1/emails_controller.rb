# frozen_string_literal: true

module Api
  module V1
    class EmailsController < BaseController
      def index
        inbox = InboxRecord.find_by!(id: params[:inbox_id], project_id: @current_project.id)

        result = Inboxed::ReadModels::EmailList.for_inbox(
          inbox.id,
          limit: pagination_limit,
          after: params[:after]
        )

        render_collection(:emails, result[:records], result, serializer: EmailListSerializer)
      end

      def show
        email = find_scoped_email(params[:id])
        render_resource(:email, email, serializer: EmailDetailSerializer)
      end

      def raw
        email = find_scoped_email(params[:id])
        send_data email.raw_source,
          type: "text/plain; charset=utf-8",
          disposition: 'inline; filename="email.eml"'
      end

      def destroy
        email = find_scoped_email(params[:id])
        Inboxed::Services::DeleteEmail.new.call(email_id: email.id)
        head :no_content
      end

      def purge
        inbox = InboxRecord.find_by!(id: params[:inbox_id], project_id: @current_project.id)
        deleted = Inboxed::Services::PurgeInbox.new.call(inbox_id: inbox.id)
        render json: {deleted_count: deleted}
      end

      def wait
        result = Inboxed::Services::WaitForEmail.new.call(
          project_id: @current_project.id,
          inbox_address: params[:inbox_address],
          subject_pattern: params[:subject_pattern],
          timeout_seconds: params[:timeout_seconds]
        )

        if result
          render_resource(:email, result, serializer: EmailDetailSerializer)
        else
          head :no_content
        end
      end

      private

      def find_scoped_email(id)
        EmailRecord
          .includes(:attachments)
          .joins(:inbox)
          .where(inboxes: {project_id: @current_project.id})
          .find(id)
      end
    end
  end
end
