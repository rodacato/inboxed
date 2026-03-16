# frozen_string_literal: true

module Inboxed
  module Services
    class DeleteHttpEndpoint
      def initialize(event_store: EventStore::Store)
        @event_store = event_store
      end

      def call(token:, project_id:)
        endpoint = HttpEndpointRecord
          .where(project_id: project_id)
          .find_by!(token: token)

        endpoint_id = endpoint.id

        endpoint.destroy!

        @event_store.publish(
          stream: "HttpEndpoint-#{endpoint_id}",
          events: [
            Events::HttpEndpointDeleted.new(
              data: {
                endpoint_id: endpoint_id,
                project_id: project_id
              }
            )
          ]
        )

        ActionCable.server.broadcast(
          "project_#{project_id}",
          {type: "endpoint_deleted", endpoint_id: endpoint_id}
        )
      end
    end
  end
end
