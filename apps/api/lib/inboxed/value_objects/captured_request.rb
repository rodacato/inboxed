# frozen_string_literal: true

module Inboxed
  module ValueObjects
    class CapturedRequest < Dry::Struct
      attribute :method, Types::String
      attribute :path, Types::String.optional.default(nil)
      attribute :query_string, Types::String.optional.default(nil)
      attribute :headers, Types::Hash.default({}.freeze)
      attribute :body, Types::String.optional.default(nil)
      attribute :content_type, Types::String.optional.default(nil)
      attribute :ip_address, Types::String.optional.default(nil)
      attribute :size_bytes, Types::Coercible::Integer.default(0)
    end
  end
end
