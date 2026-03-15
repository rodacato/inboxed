# frozen_string_literal: true

# Persistence-only AR model for the events table.
# Business logic lives in Inboxed::EventStore::Store.
class EventRecord < ApplicationRecord
  self.table_name = "events"

  scope :in_stream, ->(name) { where(stream_name: name).order(:stream_position) }
  scope :by_type, ->(type) { where(event_type: type) }
  scope :after_position, ->(pos) { where("stream_position > ?", pos) }
  scope :by_correlation, ->(id) { where("metadata->>'correlation_id' = ?", id) }
  scope :by_causation, ->(id) { where("metadata->>'causation_id' = ?", id) }
end
