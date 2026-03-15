# frozen_string_literal: true

module Inboxed
  module Repositories
    class WebhookEndpointRepository
      def create(project_id:, url:, event_types:, description: nil)
        WebhookEndpointRecord.create!(
          id: SecureRandom.uuid,
          project_id: project_id,
          url: url,
          event_types: event_types,
          secret: generate_secret,
          description: description,
          status: "active"
        )
      end

      def find(id)
        WebhookEndpointRecord.find(id)
      end

      def find_for_project(id, project_id:)
        WebhookEndpointRecord.find_by!(id: id, project_id: project_id)
      end

      def list_for_project(project_id)
        WebhookEndpointRecord.where(project_id: project_id).order(created_at: :desc)
      end

      def active_for(project_id:, event_type:)
        WebhookEndpointRecord
          .where(project_id: project_id)
          .active_or_failing
          .for_event(event_type)
      end

      def update(record, attributes)
        record.update!(attributes)
        record
      end

      def destroy(record)
        record.destroy!
      end

      def record_success(record)
        record.update!(failure_count: 0, status: "active")
      end

      def record_failure(record)
        new_count = record.failure_count + 1
        new_status = if new_count >= 10
          "disabled"
        elsif new_count >= 3
          "failing"
        else
          record.status
        end
        record.update!(failure_count: new_count, status: new_status)
      end

      private

      def generate_secret
        "whsec_#{SecureRandom.hex(32)}"
      end
    end
  end
end
