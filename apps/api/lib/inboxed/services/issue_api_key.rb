# frozen_string_literal: true

module Inboxed
  module Services
    class IssueApiKey
      def initialize(event_store: EventStore::Store)
        @event_store = event_store
      end

      def call(project_id:, label: nil)
        token = SecureRandom.hex(32)
        id = SecureRandom.uuid
        digest = BCrypt::Password.create(token)

        aggregate = @event_store.load_aggregate(Aggregates::ProjectAggregate, project_id)
        aggregate.issue_api_key(id: id, label: label, token_digest: digest)

        @event_store.publish(
          stream: aggregate.stream_name,
          events: aggregate.pending_events
        )

        ApiKeyRecord.create!(
          id: id,
          project_id: project_id,
          token_prefix: token[0, 8],
          token_digest: digest,
          label: label
        )

        aggregate.clear_pending_events
        {id: id, token: token, token_prefix: token[0, 8], label: label}
      end
    end
  end
end
