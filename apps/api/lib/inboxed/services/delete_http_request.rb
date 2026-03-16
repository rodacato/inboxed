# frozen_string_literal: true

module Inboxed
  module Services
    class DeleteHttpRequest
      def call(id:, token:, project_id:)
        endpoint = HttpEndpointRecord
          .where(project_id: project_id)
          .find_by!(token: token)

        request = endpoint.requests.find(id)
        request.destroy!

        HttpEndpointRecord.where(id: endpoint.id)
          .update_all("request_count = GREATEST(request_count - 1, 0)")
      end
    end
  end
end
