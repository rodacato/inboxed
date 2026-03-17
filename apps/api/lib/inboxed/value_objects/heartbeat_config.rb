# frozen_string_literal: true

module Inboxed
  module ValueObjects
    class HeartbeatConfig < Dry::Struct
      attribute :expected_interval_seconds, Types::Coercible::Integer.constrained(gt: 0)
      attribute :status, HeartbeatStatus
      attribute :last_ping_at, Types::Time.optional.default(nil)
      attribute :status_changed_at, Types::Time.optional.default(nil)

      def evaluate(now: Time.current)
        return :pending if last_ping_at.nil?

        elapsed = now - last_ping_at

        if elapsed <= expected_interval_seconds
          :healthy
        elsif elapsed <= expected_interval_seconds * 2
          :late
        else
          :down
        end
      end
    end
  end
end
