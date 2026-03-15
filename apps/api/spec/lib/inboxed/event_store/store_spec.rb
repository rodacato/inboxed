# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::EventStore::Store do
  let(:stream) { "TestAggregate-#{SecureRandom.uuid}" }

  let(:test_event_class) do
    Class.new(Inboxed::Events::BaseEvent) do
      def self.name = "TestEvent"
    end
  end

  before { Inboxed::EventStore::Bus.clear }

  describe ".publish" do
    it "persists events to the stream" do
      event = test_event_class.new(data: {key: "value"})

      described_class.publish(stream: stream, events: [event])

      record = EventRecord.in_stream(stream).first
      expect(record).to be_present
      expect(record.stream_position).to eq(0)
      expect(record.event_type).to eq("TestEvent")
      expect(record.data).to eq({"key" => "value"})
    end

    it "increments stream position for each event" do
      events = 3.times.map { |i| test_event_class.new(data: {index: i}) }

      described_class.publish(stream: stream, events: events)

      positions = EventRecord.in_stream(stream).pluck(:stream_position)
      expect(positions).to eq([0, 1, 2])
    end

    it "continues position from existing events" do
      described_class.publish(stream: stream, events: [test_event_class.new])
      described_class.publish(stream: stream, events: [test_event_class.new])

      positions = EventRecord.in_stream(stream).pluck(:stream_position)
      expect(positions).to eq([0, 1])
    end

    it "stores correlation and causation IDs in metadata" do
      event = test_event_class.new
      described_class.publish(
        stream: stream,
        events: [event],
        metadata: {correlation_id: "corr-123", causation_id: "cause-456"}
      )

      record = EventRecord.in_stream(stream).first
      expect(record.metadata["correlation_id"]).to eq("corr-123")
      expect(record.metadata["causation_id"]).to eq("cause-456")
    end

    it "dispatches events via the bus after persistence" do
      received = []
      Inboxed::EventStore::Bus.subscribe(test_event_class) { |e| received << e }

      event = test_event_class.new(data: {dispatched: true})
      described_class.publish(stream: stream, events: [event])

      expect(received.size).to eq(1)
      expect(received.first.data).to eq({dispatched: true})
    end

    it "accepts a single event (not wrapped in array)" do
      event = test_event_class.new(data: {single: true})
      described_class.publish(stream: stream, events: event)

      expect(EventRecord.in_stream(stream).count).to eq(1)
    end
  end

  describe ".read_stream" do
    it "returns events in order" do
      events = 3.times.map { |i| test_event_class.new(data: {index: i}) }
      described_class.publish(stream: stream, events: events)

      result = described_class.read_stream(stream)

      expect(result.size).to eq(3)
      expect(result.map { |e| e.data[:index] }).to eq([0, 1, 2])
    end

    it "returns empty array for non-existent stream" do
      expect(described_class.read_stream("NonExistent-#{SecureRandom.uuid}")).to eq([])
    end

    it "supports reading after a position" do
      events = 5.times.map { |i| test_event_class.new(data: {index: i}) }
      described_class.publish(stream: stream, events: events)

      result = described_class.read_stream(stream, after: 2)

      expect(result.size).to eq(2)
      expect(result.map { |e| e.data[:index] }).to eq([3, 4])
    end
  end

  describe ".read_by_correlation" do
    it "finds events across streams by correlation ID" do
      stream2 = "OtherAggregate-#{SecureRandom.uuid}"
      correlation = "request-#{SecureRandom.uuid}"

      described_class.publish(
        stream: stream,
        events: [test_event_class.new(data: {source: "first"})],
        metadata: {correlation_id: correlation}
      )
      described_class.publish(
        stream: stream2,
        events: [test_event_class.new(data: {source: "second"})],
        metadata: {correlation_id: correlation}
      )

      result = described_class.read_by_correlation(correlation)

      expect(result.size).to eq(2)
      expect(result.map { |e| e.data[:source] }).to eq(["first", "second"])
    end
  end

  describe ".load_aggregate" do
    let(:aggregate_class) do
      ec = test_event_class
      Class.new do
        include Inboxed::EventStore::AggregateRoot

        def self.name = "TestAggregate"
        def self.stream_prefix = "TestAggregate"

        attr_reader :total

        on(ec) do |event|
          @total = (@total || 0) + (event.data[:amount] || 0)
        end
      end
    end

    it "rebuilds aggregate state from events" do
      # Stub constantize so deserialization finds our anonymous class
      allow_any_instance_of(String).to receive(:constantize).and_call_original
      stub_const("TestEvent", test_event_class)

      uuid = SecureRandom.uuid
      stream_name = "TestAggregate-#{uuid}"

      described_class.publish(
        stream: stream_name,
        events: [
          test_event_class.new(data: {amount: 10}),
          test_event_class.new(data: {amount: 20}),
          test_event_class.new(data: {amount: 5})
        ]
      )

      aggregate = described_class.load_aggregate(aggregate_class, uuid)

      expect(aggregate.id).to eq(uuid)
      expect(aggregate.total).to eq(35)
      expect(aggregate.version).to eq(2) # 0-indexed: 3 events = version 2
      expect(aggregate.pending_events).to be_empty
    end
  end
end
