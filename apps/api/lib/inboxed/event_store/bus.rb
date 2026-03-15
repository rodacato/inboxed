# frozen_string_literal: true

module Inboxed
  module EventStore
    # Synchronous in-memory event bus.
    # Handlers are registered per event type and dispatched after persistence.
    class Bus
      class << self
        def instance
          @instance ||= new
        end

        delegate :subscribe, :dispatch, :clear, to: :instance
      end

      def initialize
        @handlers = Hash.new { |h, k| h[k] = [] }
      end

      # Subscribe a handler (block or callable) to an event type.
      #
      #   Bus.subscribe(Inboxed::Events::MessageReceived) do |event|
      #     # handle
      #   end
      #
      #   Bus.subscribe(Inboxed::Events::MessageReceived, MyHandler)
      #
      def subscribe(event_class, handler = nil, &block)
        callable = handler || block
        raise ArgumentError, "provide a handler or block" unless callable

        @handlers[event_class.name] << callable
      end

      # Dispatch an event to all registered handlers.
      # Called by Store after persisting the event.
      def dispatch(event)
        handlers_for(event).each do |handler|
          handler.respond_to?(:call) ? handler.call(event) : handler.handle(event)
        end
      end

      # Clear all subscriptions. Useful in tests.
      def clear
        @handlers.clear
      end

      private

      def handlers_for(event)
        @handlers[event.event_type] || []
      end
    end
  end
end
