# frozen_string_literal: true

module Inboxed
  module ReadModels
    class EmailDetail
      def self.find(email_id)
        EmailRecord.includes(:attachments).find(email_id)
      end
    end
  end
end
