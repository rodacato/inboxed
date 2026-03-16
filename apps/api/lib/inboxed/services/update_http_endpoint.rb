# frozen_string_literal: true

module Inboxed
  module Services
    class UpdateHttpEndpoint
      def call(token:, project_id:, params:)
        endpoint = HttpEndpointRecord
          .where(project_id: project_id)
          .find_by!(token: token)

        endpoint.update!(params.except(:endpoint_type, :token))
        endpoint
      end
    end
  end
end
