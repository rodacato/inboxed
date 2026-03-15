# frozen_string_literal: true

module Inboxed
  module Repositories
    class InboxRepository
      def find_or_create_by_address(project_id:, address:)
        InboxRecord.find_or_create_by!(address: address) do |r|
          r.id = SecureRandom.uuid
          r.project_id = project_id
        end
      end

      def find_by_id(id)
        InboxRecord.find_by(id: id)
      end

      def increment_email_count(inbox_id)
        InboxRecord.where(id: inbox_id).update_counters(email_count: 1)
      end
    end
  end
end
