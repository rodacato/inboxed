# frozen_string_literal: true

module Inboxed
  module Services
    class CreateProject
      def initialize(event_store: EventStore::Store)
        @event_store = event_store
      end

      def call(name:, slug:, default_ttl_hours: nil, max_inbox_count: 100)
        id = SecureRandom.uuid

        aggregate = Aggregates::ProjectAggregate.new(id)
        aggregate.create(name: name, slug: slug)

        @event_store.publish(
          stream: aggregate.stream_name,
          events: aggregate.pending_events
        )

        ProjectRecord.create!(
          id: id,
          name: name,
          slug: slug,
          default_ttl_hours: default_ttl_hours,
          max_inbox_count: max_inbox_count
        )

        aggregate.clear_pending_events
        id
      end
    end
  end
end
