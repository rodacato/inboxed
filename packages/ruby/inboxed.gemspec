Gem::Specification.new do |spec|
  spec.name          = "inboxed"
  spec.version       = "0.2.0"
  spec.authors       = ["Inboxed"]
  spec.summary       = "Lightweight client for the Inboxed email testing API"
  spec.description   = "HTTP client with extraction helpers for verifying emails in automated tests. Works with RSpec, Minitest, Capybara, or any Ruby test framework."
  spec.homepage      = "https://github.com/inboxed/inboxed"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.files         = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]

  # Zero external dependencies — uses only Ruby stdlib
end
