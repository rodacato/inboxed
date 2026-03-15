# 006 — Testing Helpers

> Lightweight client libraries in TypeScript and Ruby, with integration guides for popular test frameworks.

**Phase:** Phase 5 — Testing Helpers
**Status:** accepted
**Release:** —
**Depends on:** [003 — REST API](003-rest-api.md), [005 — MCP Server](005-mcp-server.md) (extraction patterns only)
**ADRs:** [ADR-015 Client Architecture](../adrs/015-testing-helper-architecture.md), [ADR-016 Distribution](../adrs/016-package-distribution.md)

---

## 1. Objective

Ship two **lightweight API client libraries** — one in TypeScript, one in Ruby — that make email verification flows in automated tests deterministic and trivial. Complement them with **integration guides** showing how to use the client from Playwright, Vitest, RSpec, Minitest, Cypress, and others.

These are **not** framework-specific SDKs. They're HTTP clients with extraction helpers that work with any test runner.

**Before Inboxed client:**
```typescript
// 😬 Fragile, timing-dependent
await page.click("#signup");
await new Promise(r => setTimeout(r, 5000)); // pray the email arrived
const res = await fetch("http://localhost:3000/api/v1/inboxes?address=test@mail.inboxed.dev", {
  headers: { Authorization: "Bearer ..." }
});
// ... 20 more lines of manual parsing
```

**After Inboxed client:**
```typescript
// ✅ Deterministic, zero sleeps
await page.click("#signup");
const email = await inboxed.waitForEmail("test@mail.inboxed.dev");
const code = await inboxed.extractCode("test@mail.inboxed.dev");
```

## 2. Current State

- REST API (spec 003) provides all endpoints, including `POST /api/v1/emails/wait` for long-polling
- MCP server (spec 005) defines extraction patterns that clients will mirror
- No client library code exists yet
- No `packages/` directory in the monorepo yet

## 3. What This Spec Delivers

### 3.1 TypeScript Client (`inboxed`)

Framework-agnostic HTTP client with extraction helpers. Works with Playwright, Vitest, Jest, Cypress, or any Node.js test runner.

### 3.2 Ruby Client (`inboxed`)

Framework-agnostic HTTP client with extraction helpers. Works with RSpec, Minitest, Capybara, or any Ruby test framework.

### 3.3 Integration Guides

Copy-pasteable documentation showing how to wire the client into popular frameworks:
- Playwright (TypeScript)
- Vitest / Jest (TypeScript)
- Cypress (TypeScript)
- RSpec + Capybara (Ruby)
- Minitest (Ruby)

---

## 4. TypeScript Client Specification

### 4.1 Public API

```typescript
import { InboxedClient, InboxedTimeoutError } from "inboxed";

const inboxed = new InboxedClient({
  apiUrl: process.env.INBOXED_API_URL ?? "http://localhost:3000",
  apiKey: process.env.INBOXED_API_KEY!,
});

// Core operations
await inboxed.waitForEmail(inbox, options?)    // → Email (throws on timeout)
await inboxed.getLatestEmail(inbox)            // → Email | null
await inboxed.listEmails(inbox, options?)      // → Email[]
await inboxed.searchEmails(query, options?)    // → Email[]
await inboxed.deleteInbox(inbox)               // → void

// Extraction (operates on latest email)
await inboxed.extractCode(inbox, options?)     // → string | null
await inboxed.extractLink(inbox, options?)     // → string | null
await inboxed.extractValue(inbox, label, options?) // → string | null
```

### 4.2 Full Interface

```typescript
interface InboxedClientOptions {
  apiUrl: string;
  apiKey: string;
}

interface WaitOptions {
  subject?: string | RegExp;   // Filter by subject
  timeout?: number;            // ms, default: 30_000
}

interface ListOptions {
  limit?: number;              // default: 10
}

interface ExtractOptions {
  pattern?: string | RegExp;   // Custom regex override
}

interface Email {
  id: string;
  from: string;
  to: string[];
  subject: string;
  bodyText: string | null;
  bodyHtml: string | null;
  receivedAt: Date;
}

class InboxedClient {
  constructor(options: InboxedClientOptions);

  waitForEmail(inbox: string, options?: WaitOptions): Promise<Email>;
  getLatestEmail(inbox: string): Promise<Email | null>;
  listEmails(inbox: string, options?: ListOptions): Promise<Email[]>;
  searchEmails(query: string, options?: ListOptions): Promise<Email[]>;
  deleteInbox(inbox: string): Promise<void>;

  extractCode(inbox: string, options?: ExtractOptions): Promise<string | null>;
  extractLink(inbox: string, options?: ExtractOptions): Promise<string | null>;
  extractValue(inbox: string, label: string, options?: ExtractOptions): Promise<string | null>;
}
```

### 4.3 Error Handling

```typescript
class InboxedError extends Error { }
class InboxedTimeoutError extends InboxedError { }   // wait expired
class InboxedNotFoundError extends InboxedError { }   // inbox doesn't exist
class InboxedAuthError extends InboxedError { }       // invalid API key
```

- **`waitForEmail` timeout → throws `InboxedTimeoutError`**. A missing email is usually a test failure.
- **Extraction miss → returns `null`**. The email exists, just doesn't contain the expected data. The test decides.

### 4.4 Integration Guide: Playwright

```typescript
// tests/fixtures.ts
import { test as base } from "@playwright/test";
import { InboxedClient } from "inboxed";

export const test = base.extend<{ inboxed: InboxedClient }>({
  inboxed: async ({}, use) => {
    const client = new InboxedClient({
      apiUrl: process.env.INBOXED_API_URL ?? "http://localhost:3000",
      apiKey: process.env.INBOXED_API_KEY!,
    });
    await use(client);
  },
});

export { expect } from "@playwright/test";
```

```typescript
// tests/signup.spec.ts
import { test, expect } from "./fixtures";

test("signup and verify email", async ({ page, inboxed }) => {
  const email = "test@mail.inboxed.dev";

  await page.goto("/signup");
  await page.fill('[name="email"]', email);
  await page.click('button[type="submit"]');

  await inboxed.waitForEmail(email, { subject: /verify/i });
  const code = await inboxed.extractCode(email);

  await page.fill('[name="code"]', code!);
  await page.click('button[type="submit"]');
  await expect(page.locator("h1")).toContainText("Welcome");

  await inboxed.deleteInbox(email);
});
```

### 4.5 Integration Guide: Vitest / Jest

```typescript
// tests/email-flow.test.ts
import { describe, it, expect, beforeAll } from "vitest";
import { InboxedClient } from "inboxed";

const inboxed = new InboxedClient({
  apiUrl: process.env.INBOXED_API_URL ?? "http://localhost:3000",
  apiKey: process.env.INBOXED_API_KEY!,
});

describe("password reset", () => {
  const email = "reset@mail.inboxed.dev";

  afterAll(() => inboxed.deleteInbox(email));

  it("sends reset email with valid link", async () => {
    await triggerPasswordReset(email);

    const message = await inboxed.waitForEmail(email, { subject: /reset/i });
    expect(message.subject).toContain("Reset");

    const link = await inboxed.extractLink(email, { pattern: /reset/ });
    expect(link).toContain("/reset?token=");
  });
});
```

### 4.6 Integration Guide: Cypress

```typescript
// cypress/support/commands.ts
import { InboxedClient } from "inboxed";

const inboxed = new InboxedClient({
  apiUrl: Cypress.env("INBOXED_API_URL") ?? "http://localhost:3000",
  apiKey: Cypress.env("INBOXED_API_KEY"),
});

Cypress.Commands.add("waitForEmail", (inbox: string, options?) => {
  return cy.wrap(inboxed.waitForEmail(inbox, options));
});

Cypress.Commands.add("extractCode", (inbox: string) => {
  return cy.wrap(inboxed.extractCode(inbox));
});
```

```typescript
// cypress/e2e/signup.cy.ts
it("verifies email after signup", () => {
  const email = "test@mail.inboxed.dev";

  cy.visit("/signup");
  cy.get('[name="email"]').type(email);
  cy.get('button[type="submit"]').click();

  cy.waitForEmail(email, { subject: /verify/i });
  cy.extractCode(email).then((code) => {
    cy.get('[name="code"]').type(code!);
    cy.get('button[type="submit"]').click();
  });
});
```

---

## 5. Ruby Client Specification

### 5.1 Public API

```ruby
require "inboxed"

Inboxed.configure do |config|
  config.api_url = ENV.fetch("INBOXED_API_URL", "http://localhost:3000")
  config.api_key = ENV["INBOXED_API_KEY"]
end

# Core operations
Inboxed.wait_for_email(inbox, subject: nil, timeout: 30)  # → Email (raises on timeout)
Inboxed.latest_email(inbox)                                 # → Email | nil
Inboxed.list_emails(inbox, limit: 10)                       # → Array<Email>
Inboxed.search_emails(query, limit: 10)                     # → Array<Email>
Inboxed.delete_inbox(inbox)                                  # → nil

# Extraction (operates on latest email)
Inboxed.extract_code(inbox, pattern: nil)                    # → String | nil
Inboxed.extract_link(inbox, pattern: nil)                    # → String | nil
Inboxed.extract_value(inbox, label:, pattern: nil)           # → String | nil
```

### 5.2 Data Classes

```ruby
module Inboxed
  class Email
    attr_reader :id, :from, :to, :subject, :body_text, :body_html, :received_at
  end

  class Configuration
    attr_accessor :api_url, :api_key
  end

  class Error < StandardError; end
  class TimeoutError < Error; end
  class NotFoundError < Error; end
  class AuthError < Error; end
end
```

### 5.3 Dependencies

**Zero external gems.** Uses only Ruby stdlib:
- `net/http` for HTTP calls
- `json` for parsing
- `uri` for URL handling

### 5.4 Integration Guide: RSpec + Capybara

```ruby
# spec/support/inboxed.rb
require "inboxed"

Inboxed.configure do |config|
  config.api_url = ENV.fetch("INBOXED_API_URL", "http://localhost:3000")
  config.api_key = ENV["INBOXED_API_KEY"]
end

RSpec.configure do |config|
  # Optional: clean up inboxes after each test
  config.after(:each, :inboxed) do |example|
    if (inbox = example.metadata[:inbox])
      Inboxed.delete_inbox(inbox)
    end
  end
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

### 5.5 Integration Guide: Minitest

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

---

## 6. Shared Extraction Behavior

Both clients implement identical extraction logic. The canonical patterns are defined in spec 005 (MCP Server), section 4.4-4.6.

### 6.1 `extractCode` / `extract_code`

| Input | Expected Output |
|-------|----------------|
| `"Your code is 482910"` | `"482910"` |
| `"Code: 1234"` | `"1234"` |
| `"Use 12345678 to verify"` | `"12345678"` |
| `"No code here"` | `null` / `nil` |
| `"First 111 then 222333"` | `"222333"` (last match) |
| Custom pattern `[A-Z]{3}-\d{4}`: `"Code: AXK-9281"` | `"AXK-9281"` |

**Rules:** search `body_text` first, fall back to stripped `body_html`. Default pattern `\b\d{4,8}\b`. Return **last** match.

### 6.2 `extractLink` / `extract_link`

| Input | Expected Output |
|-------|----------------|
| `"Click https://app.com/verify?t=abc to verify"` | `"https://app.com/verify?t=abc"` |
| `"<a href='https://app.com/reset'>Reset</a>"` (HTML only) | `"https://app.com/reset"` |
| `"No links here"` | `null` / `nil` |
| Pattern `/verify/`: `"See https://app.com/home and https://app.com/verify?t=x"` | `"https://app.com/verify?t=x"` |

**Rules:** search `body_text` URLs first, fall back to `href` parsing in `body_html`. Return first URL (or first matching pattern).

### 6.3 `extractValue` / `extract_value`

| Input (label) | Email Body | Expected Output |
|---------------|-----------|----------------|
| `"password"` | `"Temporary password: xK9#mP2!"` | `"xK9#mP2!"` |
| `"username"` | `"Your username: user_8a7c3f"` | `"user_8a7c3f"` |
| `"reference"` | `"Reference #: ORD-99281"` | `"ORD-99281"` |
| `"password"` | `"No password here"` | `null` / `nil` |

**Rules:** pattern `{label}[:\#\s]\s*(\S+)` (case-insensitive). Search `body_text` first, fall back to stripped `body_html`. Return first match.

---

## 7. Technical Decisions

### 7.1 Decision: Lightweight Clients over Framework-Specific SDKs

See [ADR-015](../adrs/015-testing-helper-architecture.md). Client libraries are framework-agnostic HTTP clients, not Playwright fixtures or RSpec matchers. Framework integration is documented, not packaged.

### 7.2 Decision: Monorepo with Deferred Publishing

See [ADR-016](../adrs/016-package-distribution.md). Clients live in `packages/` within the monorepo. Install from source/git initially. Publish to npm/RubyGems when there's demand.

### 7.3 Decision: Timeout Throws, Extraction Returns Null

- **`waitForEmail` timeout → exception.** A missing email is usually a test failure. Throwing makes the test fail fast with a clear message.
- **`extractCode`/`extractLink`/`extractValue` miss → `null`/`nil`.** The email exists but doesn't contain the expected data. The test asserts on null.

Matches the MCP server convention (ADR-014).

### 7.4 Decision: Zero External Dependencies for Ruby Gem

- **Options considered:** (A) Use Faraday or HTTParty, (B) Use Ruby stdlib only
- **Chosen:** B — Ruby stdlib (`net/http`, `json`, `uri`)
- **Why:** The HTTP surface is small (6 endpoints). Adding a gem dependency forces users to manage version conflicts. `net/http` is sufficient and always available.
- **Trade-offs:** Slightly more verbose HTTP code. Worth it for zero-dependency install.

### 7.5 Decision: TypeScript Client Uses Native Fetch

- **Options considered:** (A) Axios, (B) node-fetch, (C) Native `fetch` (Node 18+)
- **Chosen:** C — native `fetch`
- **Why:** Available in Node 18+. Inboxed targets Node 22. Zero dependencies.
- **Trade-offs:** Requires Node 18+. All supported test runners already require this.

---

## 8. Implementation Plan

### Step 1: Create Package Structure

```bash
mkdir -p packages/typescript/src packages/typescript/__tests__
mkdir -p packages/ruby/lib/inboxed packages/ruby/spec
```

Initialize `package.json` (name: `inboxed`, main: `dist/index.js`) and `inboxed.gemspec`.

### Step 2: TypeScript — Client

Create `packages/typescript/src/client.ts`:
- `InboxedClient` class implementing the full public API
- HTTP calls via native `fetch` with Bearer auth
- Inbox resolution by address (same as MCP server)
- Typed error classes (`InboxedTimeoutError`, etc.)

### Step 3: TypeScript — Extraction

Create `packages/typescript/src/extract.ts`:
- Port extraction functions from MCP spec (spec 005, Step 4)
- `extractCode()`, `extractUrls()`, `extractLabeledValue()`, `stripHtml()`
- Identical behavior to MCP server helpers

### Step 4: TypeScript — Tests

Create `packages/typescript/__tests__/`:
- `client.test.ts` — mock fetch, verify API calls and error handling
- `extract.test.ts` — all test cases from section 6

### Step 5: Ruby — Client

Create `packages/ruby/lib/inboxed/client.rb`:
- `Inboxed::Client` class with all operations
- `Net::HTTP` with Bearer auth
- Inbox resolution by address
- Error mapping to typed exceptions

### Step 6: Ruby — Extraction

Create `packages/ruby/lib/inboxed/extract.rb`:
- `Inboxed::Extract` module with `.code()`, `.link()`, `.value()`, `.strip_html()`
- Same behavior and test cases as TypeScript version

### Step 7: Ruby — Module API

Create `packages/ruby/lib/inboxed.rb`:
- Top-level `Inboxed` module with `configure`, `wait_for_email`, `extract_code`, etc.
- Delegates to `Client` and `Extract` internally
- `Configuration` class for `api_url` and `api_key`

### Step 8: Ruby — Tests

Create `packages/ruby/spec/`:
- `client_spec.rb` — stub HTTP, verify API calls
- `extract_spec.rb` — all test cases from section 6

### Step 9: Integration Guides

Write documentation (in each package's `README.md`) showing how to use the client from:

| Framework | Guide Covers |
|-----------|-------------|
| Playwright | Custom fixture setup (15 lines) |
| Vitest / Jest | Direct import, beforeAll/afterAll pattern |
| Cypress | Custom commands wrapping the client |
| RSpec + Capybara | Setup in `spec/support/`, cleanup hooks |
| Minitest | Setup in `test_helper.rb` |

### Step 10: Integration Test

End-to-end test using the TypeScript client against a running Inboxed instance:
1. Send email via SMTP
2. `waitForEmail` → receives it
3. `extractCode` → returns the code
4. `deleteInbox` → cleans up

---

## 9. File Structure

```
packages/
├── typescript/                     # inboxed (npm)
│   ├── package.json
│   ├── tsconfig.json
│   ├── vitest.config.ts
│   ├── README.md                   # API docs + Playwright/Vitest/Cypress guides
│   └── src/
│       ├── index.ts                # Public exports
│       ├── client.ts               # InboxedClient class
│       ├── extract.ts              # extractCode, extractUrls, extractLabeledValue
│       ├── errors.ts               # InboxedError, TimeoutError, NotFoundError, AuthError
│       ├── types.ts                # Email, InboxedClientOptions
│       └── __tests__/
│           ├── client.test.ts
│           └── extract.test.ts
│
└── ruby/                           # inboxed (gem)
    ├── inboxed.gemspec
    ├── Gemfile
    ├── README.md                   # API docs + RSpec/Minitest guides
    └── lib/
        ├── inboxed.rb              # Top-level module: configure, wait_for_email, etc.
        └── inboxed/
            ├── client.rb           # HTTP client (Net::HTTP)
            ├── configuration.rb    # Config object
            ├── email.rb            # Email value object
            ├── errors.rb           # Error classes
            └── extract.rb          # Extraction helpers
    └── spec/
        ├── client_spec.rb
        └── extract_spec.rb
```

---

## 10. Exit Criteria

### TypeScript Client

- [ ] **EC-001:** `InboxedClient` instantiates with `apiUrl` and `apiKey`
- [ ] **EC-002:** `waitForEmail` blocks until email arrives, resolves with `Email` object
- [ ] **EC-003:** `waitForEmail` throws `InboxedTimeoutError` after timeout expires
- [ ] **EC-004:** `extractCode` returns a 6-digit code from plain text email
- [ ] **EC-005:** `extractCode` returns `null` when no code found
- [ ] **EC-006:** `extractLink` returns a verification URL from HTML email
- [ ] **EC-007:** `extractValue` extracts a temporary password by label
- [ ] **EC-008:** `deleteInbox` removes inbox and all emails
- [ ] **EC-009:** All extraction test cases from section 6 pass
- [ ] **EC-010:** Zero runtime dependencies (native `fetch` only)
- [ ] **EC-011:** `npm run build` succeeds with zero TypeScript errors

### Ruby Client

- [ ] **EC-012:** `Inboxed.configure` accepts `api_url` and `api_key`
- [ ] **EC-013:** `Inboxed.wait_for_email` blocks until email arrives
- [ ] **EC-014:** `Inboxed.wait_for_email` raises `Inboxed::TimeoutError` after timeout
- [ ] **EC-015:** `Inboxed.extract_code` returns a 6-digit code
- [ ] **EC-016:** `Inboxed.extract_link` returns a verification URL
- [ ] **EC-017:** `Inboxed.extract_value` extracts a labeled value
- [ ] **EC-018:** All extraction test cases from section 6 pass
- [ ] **EC-019:** Zero external gem dependencies (Ruby stdlib only)

### Integration & Documentation

- [ ] **EC-020:** End-to-end: send email → waitForEmail → extractCode → value matches
- [ ] **EC-021:** README includes working Playwright integration guide
- [ ] **EC-022:** README includes working RSpec integration guide
- [ ] **EC-023:** Both packages installable from local path

## 11. Open Questions

None — all decisions captured in ADRs 015 and 016.
