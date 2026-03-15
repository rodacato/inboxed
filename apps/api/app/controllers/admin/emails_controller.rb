# frozen_string_literal: true

module Admin
  class EmailsController < BaseController
    def index
      inbox = InboxRecord.find_by!(id: params[:inbox_id], project_id: params[:project_id])

      result = Inboxed::ReadModels::EmailList.for_inbox(
        inbox.id,
        limit: pagination_limit,
        after: params[:after]
      )

      render json: {
        emails: result[:records].map { |r| EmailListSerializer.render(r) },
        pagination: pagination_meta(result)
      }
    end

    def show
      email = EmailRecord.includes(:attachments).find(params[:id])
      render json: {email: EmailDetailSerializer.render(email, url_prefix: "/admin")}
    end

    def raw
      email = EmailRecord.find(params[:id])
      send_data email.raw_source,
        type: "text/plain; charset=utf-8",
        disposition: 'inline; filename="email.eml"'
    end

    def destroy
      email = EmailRecord.find(params[:id])
      Inboxed::Services::DeleteEmail.new.call(email_id: email.id)
      head :no_content
    end

    def purge
      inbox = InboxRecord.find_by!(id: params[:inbox_id], project_id: params[:project_id])
      deleted = Inboxed::Services::PurgeInbox.new.call(inbox_id: inbox.id)
      render json: {deleted_count: deleted}
    end
  end
end
