# frozen_string_literal: true

module Inboxed
  module EventStore
    # Mixin for aggregate roots that are rebuilt from events.
    #
    # Usage:
    #
    #   class MessageAggregate
    #     include Inboxed::EventStore::AggregateRoot
    #
    #     def self.stream_prefix = "Message"
    #
    #     on Events::MessageReceived do |event|
    #       @subject = event.data[:subject]
    #     end
    #
    #     def receive(from:, to:, subject:)
    #       apply Events::MessageReceived.new(
    #         data: { from: from, to: to, subject: subject }
    #       )
    #     end
    #   end
    #
    module AggregateRoot
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        # Override in subclass to set the stream prefix.
        # Default: class name without "Aggregate" suffix.
        def stream_prefix
          name.demodulize.delete_suffix("Aggregate")
        end

        # Build the full stream name for a given aggregate ID.
        def stream_name(id)
          "#{stream_prefix}-#{id}"
        end

        # Register an event handler for replay and apply.
        def on(event_class, &block)
          event_handlers[event_class.name] = block
        end

        def event_handlers
          @event_handlers ||= {}
        end
      end

      attr_reader :id, :version

      def initialize(id)
        @id = id
        @version = -1
        @pending_events = []
      end

      # Apply a new event (command side).
      # Records it as pending and applies the state change.
      def apply(event)
        apply_event(event)
        @pending_events << event
      end

      # Apply an existing event from the store (replay).
      # Does NOT record as pending.
      def apply_existing(event)
        apply_event(event)
        @version += 1
      end

      # Events that have been applied but not yet persisted.
      def pending_events
        @pending_events.dup.freeze
      end

      # Clear pending events after persistence.
      def clear_pending_events
        @pending_events.clear
      end

      # The stream name for this aggregate instance.
      def stream_name
        self.class.stream_name(id)
      end

      # Override in subclass to provide state for snapshots.
      def snapshot_state
        {}
      end

      # Override in subclass to restore state from a snapshot.
      def restore_from_snapshot(state)
        # no-op by default
      end

      private

      def apply_event(event)
        handler = self.class.event_handlers[event.event_type]
        instance_exec(event, &handler) if handler
      end
    end
  end
end
