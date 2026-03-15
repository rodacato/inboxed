# frozen_string_literal: true

module Inboxed
  class Error < StandardError; end
  class TimeoutError < Error; end
  class NotFoundError < Error; end
  class AuthError < Error; end
end
