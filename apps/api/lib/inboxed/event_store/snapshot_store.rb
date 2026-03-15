# frozen_string_literal: true

module Inboxed
  module EventStore
    class SnapshotStore
      SNAPSHOT_INTERVAL = 50

      class << self
        def load(stream_name, aggregate_type)
          record = SnapshotRecord.for_stream(stream_name).first
          return nil unless record
          return nil if record.aggregate_type != aggregate_type

          {
            state: record.state.deep_symbolize_keys,
            stream_position: record.stream_position,
            schema_version: record.schema_version
          }
        end

        def save(stream_name, aggregate_type:, stream_position:, state:, schema_version: 1)
          SnapshotRecord.upsert(
            {
              stream_name: stream_name,
              aggregate_type: aggregate_type,
              stream_position: stream_position,
              state: state,
              schema_version: schema_version,
              created_at: Time.current
            },
            unique_by: :stream_name
          )
        end

        def should_snapshot?(version)
          version > 0 && (version % SNAPSHOT_INTERVAL).zero?
        end
      end
    end
  end
end
