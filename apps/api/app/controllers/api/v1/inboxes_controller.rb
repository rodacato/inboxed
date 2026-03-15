# frozen_string_literal: true

module Api
  module V1
    class InboxesController < BaseController
      def index
        result = Inboxed::ReadModels::InboxList.for_project(
          @current_project.id,
          limit: pagination_limit,
          after: params[:after]
        )

        render json: {
          inboxes: result[:records].map { |r| serialize_inbox(r) },
          pagination: pagination_meta(result)
        }
      end

      def show
        inbox = InboxRecord.find_by!(id: params[:id], project_id: @current_project.id)
        render json: {inbox: serialize_inbox(inbox)}
      end

      def destroy
        inbox = InboxRecord.find_by!(id: params[:id], project_id: @current_project.id)
        Inboxed::Services::DeleteInbox.new.call(inbox_id: inbox.id)
        head :no_content
      end

      private

      def serialize_inbox(record)
        {
          id: record.id,
          address: record.address,
          email_count: record.email_count,
          created_at: record.created_at.iso8601
        }
      end
    end
  end
end
