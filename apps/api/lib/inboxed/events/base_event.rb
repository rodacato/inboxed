# frozen_string_literal: true

module Inboxed
  module Events
    class BaseEvent < Dry::Struct
      attribute :event_id, Types::String.default { SecureRandom.uuid }
      attribute :data, Types::Hash.default({}.freeze)
      attribute :metadata, Types::Hash.default({}.freeze)

      def event_type
        self.class.name
      end

      def correlation_id
        metadata[:correlation_id] || metadata["correlation_id"]
      end

      def causation_id
        metadata[:causation_id] || metadata["causation_id"]
      end

      def timestamp
        metadata[:timestamp] || metadata["timestamp"] || Time.current.iso8601
      end

      def with_metadata(extra)
        new(metadata: metadata.merge(extra))
      end
    end
  end
end
