# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::EventStore::Bus do
  subject(:bus) { described_class.new }

  let(:test_event_class) do
    Class.new(Inboxed::Events::BaseEvent) do
      def self.name = "TestEvent"
    end
  end

  after { bus.clear }

  describe "#subscribe and #dispatch" do
    it "dispatches events to registered block handlers" do
      received = []
      bus.subscribe(test_event_class) { |e| received << e }

      event = test_event_class.new(data: {foo: "bar"})
      bus.dispatch(event)

      expect(received.size).to eq(1)
      expect(received.first.data).to eq({foo: "bar"})
    end

    it "dispatches to multiple handlers" do
      results = []
      bus.subscribe(test_event_class) { |_e| results << :first }
      bus.subscribe(test_event_class) { |_e| results << :second }

      bus.dispatch(test_event_class.new)

      expect(results).to eq([:first, :second])
    end

    it "does not dispatch to handlers of other event types" do
      other_class = Class.new(Inboxed::Events::BaseEvent) do
        def self.name = "OtherEvent"
      end

      received = []
      bus.subscribe(other_class) { |e| received << e }

      bus.dispatch(test_event_class.new)

      expect(received).to be_empty
    end

    it "supports callable objects" do
      handler = double("handler", call: nil)
      bus.subscribe(test_event_class, handler)

      event = test_event_class.new
      bus.dispatch(event)

      expect(handler).to have_received(:call).with(event)
    end

    it "raises if no handler or block given" do
      expect { bus.subscribe(test_event_class) }.to raise_error(ArgumentError)
    end
  end

  describe "#clear" do
    it "removes all subscriptions" do
      received = []
      bus.subscribe(test_event_class) { |e| received << e }
      bus.clear
      bus.dispatch(test_event_class.new)

      expect(received).to be_empty
    end
  end
end
