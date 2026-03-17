# frozen_string_literal: true

module Inboxed
  module ValueObjects
    HeartbeatStatus = Types::String.enum("pending", "healthy", "late", "down")
  end
end
