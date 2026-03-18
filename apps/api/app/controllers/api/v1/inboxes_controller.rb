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

        render_collection(:inboxes, result[:records], result, serializer: InboxSerializer)
      end

      def show
        inbox = InboxRecord.find_by!(id: params[:id], project_id: @current_project.id)
        render_resource(:inbox, inbox, serializer: InboxSerializer)
      end

      def destroy
        inbox = InboxRecord.find_by!(id: params[:id], project_id: @current_project.id)
        Inboxed::Services::DeleteInbox.new.call(inbox_id: inbox.id)
        head :no_content
      end
    end
  end
end
