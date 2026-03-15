# frozen_string_literal: true

module Inboxed
  module Services
    class WaitForEmail
      MAX_TIMEOUT = 30
      POLL_INTERVAL = 1

      def call(project_id:, inbox_address:, subject_pattern: nil, timeout_seconds: 30)
        timeout = [timeout_seconds.to_i, MAX_TIMEOUT].min
        cutoff = Time.current
        deadline = Time.current + timeout

        loop do
          email = find_matching_email(project_id, inbox_address, subject_pattern, cutoff)
          return email if email
          break if Time.current >= deadline
          sleep POLL_INTERVAL
        end

        nil
      end

      private

      def find_matching_email(project_id, inbox_address, subject_pattern, since)
        scope = EmailRecord
          .joins(:inbox)
          .where(inboxes: {project_id: project_id, address: inbox_address})
          .where("emails.received_at >= ?", since)
          .order(received_at: :desc)

        if subject_pattern.present?
          scope = scope.where("emails.subject ~ ?", subject_pattern)
        end

        scope.includes(:attachments).first
      end
    end
  end
end
