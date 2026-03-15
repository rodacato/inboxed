# frozen_string_literal: true

module Inboxed
  module ValueObjects
    class AttachmentInfo < Dry::Struct
      attribute :filename, Types::NonEmpty
      attribute :content_type, Types::NonEmpty
      attribute :size_bytes, Types::Coercible::Integer
      attribute :content_id, Types::String.optional.default(nil)
      attribute :inline, Types::Bool.default(false)
    end
  end
end
