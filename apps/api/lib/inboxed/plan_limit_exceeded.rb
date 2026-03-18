# frozen_string_literal: true

module Inboxed
  class PlanLimitExceeded < StandardError
    attr_reader :limit, :current, :max

    def initialize(message = "Plan limit exceeded", limit: nil, current: nil, max: nil)
      @limit = limit
      @current = current
      @max = max
      super(message)
    end
  end
end
