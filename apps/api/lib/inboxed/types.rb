# frozen_string_literal: true

module Inboxed
  module Types
    include Dry.Types()

    Email = String.constrained(format: /\A[^@\s]+@[^@\s]+\z/)
    UUID = String.constrained(format: /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
    NonEmpty = String.constrained(min_size: 1)
    StreamName = String.constrained(format: /\A[A-Za-z][\w-]*-[0-9a-f-]{36}\z/)
    EventType = String.constrained(min_size: 1)
  end
end
