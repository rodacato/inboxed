# frozen_string_literal: true

module Inboxed
  module EventStore
    # Append-only event store backed by PostgreSQL.
    # Persists events to the events table and dispatches via Bus.
    class Store
      class ConcurrencyError < StandardError; end

      class << self
        # Publish one or more events to a stream.
        #
        #   Store.publish(
        #     stream: "Message-#{uuid}",
        #     events: [MessageReceived.new(data: {...})],
        #     metadata: { correlation_id: "abc", causation_id: nil }
        #   )
        #
        def publish(stream:, events:, metadata: {})
          events = Array(events)
          timestamp = Time.current.iso8601

          ActiveRecord::Base.transaction do
            current_position = next_position(stream)

            events.each_with_index do |event, index|
              merged_metadata = metadata
                .merge(timestamp: timestamp, event_id: event.event_id)
                .merge(event.metadata)
                .stringify_keys

              EventRecord.create!(
                stream_name: stream,
                stream_position: current_position + index,
                event_type: event.event_type,
                data: event.data,
                metadata: merged_metadata
              )
            end
          end

          # Dispatch outside transaction — handlers should not rely on
          # being inside the publishing transaction.
          events.each { |event| Bus.dispatch(event) }
        end

        # Read all events in a stream, ordered by position.
        def read_stream(stream, after: nil)
          scope = EventRecord.in_stream(stream)
          scope = scope.after_position(after) if after
          scope.map { |record| deserialize(record) }
        end

        # Read events by correlation ID across all streams.
        def read_by_correlation(correlation_id)
          EventRecord.by_correlation(correlation_id)
            .order(:id)
            .map { |record| deserialize(record) }
        end

        # Read events by causation ID across all streams.
        def read_by_causation(causation_id)
          EventRecord.by_causation(causation_id)
            .order(:id)
            .map { |record| deserialize(record) }
        end

        # Load an aggregate by replaying its event stream.
        #
        #   aggregate = Store.load_aggregate(MessageAggregate, uuid)
        #
        def load_aggregate(aggregate_class, id)
          stream = aggregate_class.stream_name(id)
          events = read_stream(stream)

          aggregate = aggregate_class.new(id)
          events.each { |event| aggregate.apply_existing(event) }
          aggregate
        end

        private

        def next_position(stream)
          last = EventRecord.where(stream_name: stream).maximum(:stream_position)
          (last || -1) + 1
        end

        def deserialize(record)
          meta = record.metadata.symbolize_keys
          stored_event_id = meta.delete(:event_id) || record.id.to_s

          event_class = record.event_type.constantize
          event_class.new(
            event_id: stored_event_id,
            data: record.data.symbolize_keys,
            metadata: meta
          )
        rescue NameError
          # Unknown event type — return a generic event
          Events::BaseEvent.new(
            event_id: stored_event_id,
            data: record.data.symbolize_keys,
            metadata: meta.merge(original_type: record.event_type)
          )
        end
      end
    end
  end
end
