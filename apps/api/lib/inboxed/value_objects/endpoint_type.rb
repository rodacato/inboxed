# frozen_string_literal: true

module Inboxed
  module ValueObjects
    EndpointType = Types::String.enum("webhook", "form", "heartbeat")
  end
end
