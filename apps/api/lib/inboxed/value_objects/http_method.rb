# frozen_string_literal: true

module Inboxed
  module ValueObjects
    HttpMethod = Types::String.enum("GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS")
  end
end
