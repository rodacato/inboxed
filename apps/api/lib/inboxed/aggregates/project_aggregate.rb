# frozen_string_literal: true

module Inboxed
  module Aggregates
    class ProjectAggregate
      include Inboxed::EventStore::AggregateRoot

      def self.stream_prefix = "Project"

      attr_reader :name, :slug

      def initialize(id)
        super
        @name = nil
        @slug = nil
      end

      def create(name:, slug:)
        apply Events::ProjectCreated.new(
          data: {project_id: id, name: name, slug: slug}
        )
      end

      def issue_api_key(id:, label:, token_digest:)
        apply Events::ApiKeyIssued.new(
          data: {project_id: self.id, api_key_id: id, label: label, token_digest: token_digest}
        )
      end

      on(Events::ProjectCreated) do |event|
        @name = event.data[:name]
        @slug = event.data[:slug]
      end

      on(Events::ApiKeyIssued) do |_event|
        # API key state tracked in AR, not in aggregate
      end
    end
  end
end
