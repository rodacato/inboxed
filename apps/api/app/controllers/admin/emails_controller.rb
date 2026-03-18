# frozen_string_literal: true

module Admin
  class EmailsController < BaseController
    def project_index
      project = current_project

      result = Inboxed::ReadModels::EmailList.for_project(
        project.id,
        limit: pagination_limit,
        after: params[:after],
        inbox_id: params[:inbox_id]
      )

      render json: {
        emails: result[:records].map { |r| EmailListSerializer.render(r) },
        pagination: pagination_meta(result)
      }
    end

    def index
      inbox = InboxRecord.find_by!(id: params[:inbox_id], project_id: current_project.id)

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
      email = find_tenant_email
      render json: {email: EmailDetailSerializer.render(email, url_prefix: "/admin")}
    end

    def raw
      email = find_tenant_email
      send_data email.raw_source,
        type: "text/plain; charset=utf-8",
        disposition: 'inline; filename="email.eml"'
    end

    def destroy
      email = find_tenant_email
      Inboxed::Services::DeleteEmail.new.call(email_id: email.id)
      head :no_content
    end

    def purge
      inbox = InboxRecord.find_by!(id: params[:inbox_id], project_id: current_project.id)
      deleted = Inboxed::Services::PurgeInbox.new.call(inbox_id: inbox.id)
      render json: {deleted_count: deleted}
    end

    private

    def find_tenant_email
      EmailRecord
        .includes(:attachments)
        .joins(inbox: :project)
        .where(projects: {id: tenant_project_ids})
        .find(params[:id])
    end
  end
end
