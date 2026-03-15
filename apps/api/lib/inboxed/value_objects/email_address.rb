# frozen_string_literal: true

module Inboxed
  module ValueObjects
    class EmailAddress < Dry::Struct
      attribute :local, Types::NonEmpty
      attribute :domain, Types::NonEmpty

      def to_s
        "#{local}@#{domain}"
      end

      def self.parse(string)
        local, domain = string.to_s.split("@", 2)
        new(local: local || "", domain: domain || "")
      end
    end
  end
end
