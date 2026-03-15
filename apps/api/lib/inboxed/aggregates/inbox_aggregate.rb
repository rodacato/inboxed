# frozen_string_literal: true

module Inboxed
  module Aggregates
    class InboxAggregate
      include Inboxed::EventStore::AggregateRoot

      def self.stream_prefix = "Inbox"

      attr_reader :project_id, :address, :email_count

      def initialize(id)
        super
        @project_id = nil
        @address = nil
        @email_count = 0
      end

      def create(project_id:, address:)
        apply Events::InboxCreated.new(
          data: {inbox_id: id, project_id: project_id, address: address}
        )
      end

      def receive_email(id:, from:, to:, subject:, source_type:, expires_at:)
        apply Events::EmailReceived.new(
          data: {
            email_id: id,
            inbox_id: self.id,
            from: from,
            to: to,
            subject: subject,
            source_type: source_type,
            expires_at: expires_at.iso8601
          }
        )
      end

      def delete_email(email_id:)
        apply Events::EmailDeleted.new(
          data: {email_id: email_id, inbox_id: id}
        )
      end

      on(Events::InboxCreated) do |event|
        @project_id = event.data[:project_id]
        @address = event.data[:address]
      end

      on(Events::EmailReceived) do |_event|
        @email_count += 1
      end

      on(Events::EmailDeleted) do |_event|
        @email_count -= 1
      end

      def snapshot_state
        {project_id: @project_id, address: @address, email_count: @email_count}
      end

      def restore_from_snapshot(state)
        @project_id = state[:project_id]
        @address = state[:address]
        @email_count = state[:email_count] || 0
      end
    end
  end
end
