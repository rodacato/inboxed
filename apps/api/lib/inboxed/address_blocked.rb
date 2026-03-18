# frozen_string_literal: true

module Inboxed
  class AddressBlocked < StandardError
    attr_reader :address

    def initialize(address)
      @address = address
      super("Address '#{address}' is blocked by the site administrator")
    end
  end
end
