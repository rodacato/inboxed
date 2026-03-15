# inboxed

Lightweight Ruby client for the Inboxed email testing API. Works with RSpec, Minitest, Capybara, or any Ruby test framework.

## Installation

```ruby
# Gemfile — from local monorepo
gem "inboxed", path: "../packages/ruby"

# Gemfile — from git
gem "inboxed", git: "https://github.com/user/inboxed", glob: "packages/ruby/*.gemspec"
```

## Quick Start

```ruby
require "inboxed"

Inboxed.configure do |config|
  config.api_url = ENV.fetch("INBOXED_API_URL", "http://localhost:3000")
  config.api_key = ENV["INBOXED_API_KEY"]
end

# Wait for an email to arrive
email = Inboxed.wait_for_email("test@mail.inboxed.dev")

# Extract a verification code
code = Inboxed.extract_code("test@mail.inboxed.dev")

# Extract a link
link = Inboxed.extract_link("test@mail.inboxed.dev", pattern: /verify|confirm/)

# Extract a labeled value
password = Inboxed.extract_value("test@mail.inboxed.dev", label: "password")

# Clean up
Inboxed.delete_inbox("test@mail.inboxed.dev")
```

## API

### Core Operations

| Method | Returns | Description |
|--------|---------|-------------|
| `Inboxed.wait_for_email(inbox, subject:, timeout:)` | `Email` | Block until email arrives (raises on timeout) |
| `Inboxed.latest_email(inbox)` | `Email \| nil` | Get the most recent email |
| `Inboxed.list_emails(inbox, limit:)` | `Array<Email>` | List emails in an inbox |
| `Inboxed.search_emails(query, limit:)` | `Array<Email>` | Full-text search |
| `Inboxed.delete_inbox(inbox)` | `nil` | Delete inbox and all emails |

### Extraction

| Method | Returns | Description |
|--------|---------|-------------|
| `Inboxed.extract_code(inbox, pattern:)` | `String \| nil` | Extract verification code |
| `Inboxed.extract_link(inbox, pattern:)` | `String \| nil` | Extract URL |
| `Inboxed.extract_value(inbox, label:, pattern:)` | `String \| nil` | Extract labeled value |

### Error Classes

| Class | When |
|-------|------|
| `Inboxed::TimeoutError` | `wait_for_email` timeout expired |
| `Inboxed::NotFoundError` | Inbox or email doesn't exist |
| `Inboxed::AuthError` | Invalid API key |

## Integration: RSpec + Capybara

```ruby
# spec/support/inboxed.rb
require "inboxed"

Inboxed.configure do |config|
  config.api_url = ENV.fetch("INBOXED_API_URL", "http://localhost:3000")
  config.api_key = ENV["INBOXED_API_KEY"]
end
```

```ruby
# spec/features/signup_spec.rb
RSpec.describe "User signup", type: :feature do
  let(:email) { "test@mail.inboxed.dev" }

  after { Inboxed.delete_inbox(email) }

  it "sends verification email and accepts code" do
    visit "/signup"
    fill_in "Email", with: email
    click_button "Sign up"

    message = Inboxed.wait_for_email(email, subject: /verify/i)
    expect(message.subject).to include("Verify")

    code = Inboxed.extract_code(email)
    expect(code).to match(/\A\d{6}\z/)

    fill_in "Code", with: code
    click_button "Verify"
    expect(page).to have_content("Welcome")
  end
end
```

## Integration: Minitest

```ruby
# test/test_helper.rb
require "inboxed"

Inboxed.configure do |config|
  config.api_url = ENV.fetch("INBOXED_API_URL", "http://localhost:3000")
  config.api_key = ENV["INBOXED_API_KEY"]
end
```

```ruby
# test/integration/signup_test.rb
class SignupTest < ActionDispatch::IntegrationTest
  def setup
    @email = "test@mail.inboxed.dev"
  end

  def teardown
    Inboxed.delete_inbox(@email)
  end

  test "sends verification code on signup" do
    post "/signup", params: { email: @email }

    message = Inboxed.wait_for_email(@email, subject: /verify/i)
    assert_match(/Verify/, message.subject)

    code = Inboxed.extract_code(@email)
    assert_match(/\A\d{6}\z/, code)
  end
end
```

## Zero Dependencies

This gem uses only Ruby stdlib (`net/http`, `json`, `uri`). No external gems required.
