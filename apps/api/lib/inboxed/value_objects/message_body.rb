# frozen_string_literal: true

module Inboxed
  module ValueObjects
    class MessageBody < Dry::Struct
      attribute :html, Types::String.optional.default(nil)
      attribute :text, Types::String.optional.default(nil)

      def empty?
        html.nil? && text.nil?
      end

      def preview(length: 200)
        source = text || html&.gsub(/<[^>]+>/, "") || ""
        source[0, length]
      end
    end
  end
end
