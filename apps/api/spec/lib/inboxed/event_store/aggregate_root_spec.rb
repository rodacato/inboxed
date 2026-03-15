# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::EventStore::AggregateRoot do
  let(:event_class) do
    Class.new(Inboxed::Events::BaseEvent) do
      def self.name = "ItemAdded"
    end
  end

  let(:aggregate_class) do
    ec = event_class
    Class.new do
      include Inboxed::EventStore::AggregateRoot

      define_method(:event_class) { ec }

      def self.name = "Cart"
      def self.stream_prefix = "Cart"

      attr_reader :items

      on(ec) do |event|
        @items ||= []
        @items << event.data[:item]
      end

      def add_item(name)
        apply event_class.new(data: {item: name})
      end
    end
  end

  describe "#apply" do
    it "applies the event and records it as pending" do
      aggregate = aggregate_class.new(SecureRandom.uuid)
      aggregate.add_item("widget")

      expect(aggregate.items).to eq(["widget"])
      expect(aggregate.pending_events.size).to eq(1)
    end

    it "accumulates multiple events" do
      aggregate = aggregate_class.new(SecureRandom.uuid)
      aggregate.add_item("widget")
      aggregate.add_item("gadget")

      expect(aggregate.items).to eq(["widget", "gadget"])
      expect(aggregate.pending_events.size).to eq(2)
    end
  end

  describe "#apply_existing" do
    it "applies event without recording as pending" do
      aggregate = aggregate_class.new(SecureRandom.uuid)
      event = event_class.new(data: {item: "restored"})

      aggregate.apply_existing(event)

      expect(aggregate.items).to eq(["restored"])
      expect(aggregate.pending_events).to be_empty
      expect(aggregate.version).to eq(0)
    end
  end

  describe "#clear_pending_events" do
    it "clears the pending list" do
      aggregate = aggregate_class.new(SecureRandom.uuid)
      aggregate.add_item("widget")
      aggregate.clear_pending_events

      expect(aggregate.pending_events).to be_empty
      expect(aggregate.items).to eq(["widget"]) # state preserved
    end
  end

  describe ".stream_name" do
    it "builds stream name from prefix and ID" do
      uuid = SecureRandom.uuid
      expect(aggregate_class.stream_name(uuid)).to eq("Cart-#{uuid}")
    end
  end
end
