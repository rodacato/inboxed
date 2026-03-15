# inboxed

Lightweight TypeScript client for the Inboxed email testing API. Works with Playwright, Vitest, Jest, Cypress, or any Node.js test runner.

## Installation

```bash
# From local monorepo
npm install ../packages/typescript

# From git
npm install github:user/inboxed#main
```

## Quick Start

```typescript
import { InboxedClient } from "inboxed";

const inboxed = new InboxedClient({
  apiUrl: process.env.INBOXED_API_URL ?? "http://localhost:3000",
  apiKey: process.env.INBOXED_API_KEY!,
});

// Wait for an email to arrive
const email = await inboxed.waitForEmail("test@mail.inboxed.dev");

// Extract a verification code
const code = await inboxed.extractCode("test@mail.inboxed.dev");

// Extract a link
const link = await inboxed.extractLink("test@mail.inboxed.dev", {
  pattern: /verify|confirm/,
});

// Extract a labeled value
const password = await inboxed.extractValue("test@mail.inboxed.dev", "password");

// Clean up
await inboxed.deleteInbox("test@mail.inboxed.dev");
```

## API

### Core Operations

| Method | Returns | Description |
|--------|---------|-------------|
| `waitForEmail(inbox, options?)` | `Email` | Block until email arrives (throws on timeout) |
| `getLatestEmail(inbox)` | `Email \| null` | Get the most recent email |
| `listEmails(inbox, options?)` | `Email[]` | List emails in an inbox |
| `searchEmails(query, options?)` | `Email[]` | Full-text search |
| `deleteInbox(inbox)` | `void` | Delete inbox and all emails |

### Extraction

| Method | Returns | Description |
|--------|---------|-------------|
| `extractCode(inbox, options?)` | `string \| null` | Extract verification code |
| `extractLink(inbox, options?)` | `string \| null` | Extract URL |
| `extractValue(inbox, label, options?)` | `string \| null` | Extract labeled value |

### Error Classes

| Class | When |
|-------|------|
| `InboxedTimeoutError` | `waitForEmail` timeout expired |
| `InboxedNotFoundError` | Inbox or email doesn't exist |
| `InboxedAuthError` | Invalid API key |

## Integration: Playwright

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

## Integration: Vitest / Jest

```typescript
import { describe, it, expect, afterAll } from "vitest";
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

## Integration: Cypress

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
