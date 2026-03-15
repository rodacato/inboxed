# frozen_string_literal: true

require "webmock/rspec"
require "inboxed"

RSpec.configure do |config|
  config.before(:each) do
    Inboxed.reset_configuration!
  end
end
