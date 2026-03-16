# frozen_string_literal: true

module Inboxed
  module Services
    class PurgeHttpRequests
      def call(token:, project_id:)
        endpoint = HttpEndpointRecord
          .where(project_id: project_id)
          .find_by!(token: token)

        deleted_count = endpoint.requests.delete_all

        HttpEndpointRecord.where(id: endpoint.id)
          .update_all(request_count: 0)

        ActionCable.server.broadcast(
          "project_#{project_id}",
          {
            type: "requests_purged",
            endpoint_id: endpoint.id,
            deleted_count: deleted_count
          }
        )

        deleted_count
      end
    end
  end
end
