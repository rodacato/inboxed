# frozen_string_literal: true

module Inboxed
  class Configuration
    attr_accessor :api_url, :api_key

    def initialize
      @api_url = ENV.fetch("INBOXED_API_URL", "http://localhost:3000")
      @api_key = ENV["INBOXED_API_KEY"]
    end
  end
end
