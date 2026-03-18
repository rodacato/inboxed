# First Test Case: Stripe + Cognito OTP Automation

> Validating Inboxed as the unified dev inbox for a real-world E2E automation flow.

---

## The Problem

A developer is building a web app with:

- **AWS Cognito** for authentication (email OTP verification)
- **Stripe** for payments (webhook notifications)
- **Claude Code (Chrome extension)** for browser automation

The automation flow requires:

1. Registering a user → Cognito sends an OTP via email → the automation needs to read it
2. Completing a Stripe checkout → Stripe sends a webhook → the automation needs to verify the payment status

Today this requires multiple disconnected tools (Mailtrap + webhook.site + manual glue). Inboxed should replace all of them.

---

## The Test Flow

```
Developer triggers automation via Claude (browser extension)
    │
    ├─ 1. Claude navigates to the app's signup page
    ├─ 2. Claude fills in email: test-user@mail.inboxed.dev
    ├─ 3. App calls Cognito → Cognito sends OTP email via SMTP
    │      └─ SMTP points to Inboxed → email captured
    ├─ 4. Claude calls MCP: extract_code("test-user@mail.inboxed.dev")
    │      └─ Returns: "482917"
    ├─ 5. Claude types OTP into verification field → user logged in
    │
    ├─ 6. Claude navigates to checkout, completes Stripe payment
    ├─ 7. Stripe sends webhook to https://inboxed.notdefined.dev/hook/:token
    │      └─ HTTP catcher captures the request
    ├─ 8. Claude calls MCP: wait_for_request(endpoint_token)
    │      └─ Returns: full webhook payload
    ├─ 9. Claude calls MCP: extract_json_field(request_id, "data.object.status")
    │      └─ Returns: "succeeded"
    └─ 10. Claude asserts payment completed → test passes
```

---

## What Inboxed Provides

### For the OTP (Inboxed Mail — SMTP Catcher)

| Step | Inboxed feature | MCP tool |
|------|----------------|----------|
| Capture Cognito's OTP email | SMTP server catches all email to `*@mail.inboxed.dev` | — |
| Wait for the email to arrive | REST API long-poll / MCP blocking call | `wait_for_email` |
| Extract the 6-digit code | Regex-based code extraction | `extract_code` |

**App configuration required:**

```
# Cognito SES/SMTP custom provider → point to Inboxed
SMTP_HOST=inboxed.notdefined.dev
SMTP_PORT=587
```

### For the Webhook (Inboxed Hooks — HTTP Catcher)

| Step | Inboxed feature | MCP tool |
|------|----------------|----------|
| Create a catch-all URL | `POST /api/v1/endpoints` → returns `/hook/:token` | `create_endpoint` |
| Receive Stripe's webhook | Public endpoint captures any HTTP method + body | — |
| Wait for the webhook to arrive | REST API long-poll / MCP blocking call | `wait_for_request` |
| Extract payment status from JSON | JSON path extraction from stored body | `extract_json_field` |
| List all received webhooks | Paginated request list | `list_requests` |

**Stripe configuration required:**

```
# Stripe Dashboard → Webhooks → Add endpoint
Endpoint URL: https://inboxed.notdefined.dev/hook/<your-token>
Events: checkout.session.completed, payment_intent.succeeded
```

---

## MCP Configuration

For Claude (browser extension or Claude Code) to interact with Inboxed directly:

```json
{
  "mcpServers": {
    "inboxed": {
      "command": "node",
      "args": ["apps/mcp/dist/index.js"],
      "env": {
        "INBOXED_API_URL": "https://inboxed.notdefined.dev/api/v1",
        "INBOXED_API_KEY": "<your-api-key>"
      }
    }
  }
}
```

### MCP Tools Used in This Test

```
# Email OTP flow
wait_for_email(inbox: "test-user@mail.inboxed.dev", timeout: 30)
extract_code(inbox: "test-user@mail.inboxed.dev")

# Stripe webhook flow
create_endpoint(label: "stripe-test")
wait_for_request(endpoint_token: "<token>", timeout: 30)
get_latest_request(endpoint_token: "<token>")
extract_json_field(request_id: "<id>", field: "data.object.status")
list_requests(endpoint_token: "<token>", limit: 10)
```

---

## Automation Script (Playwright + Inboxed Client)

A non-MCP version using the TypeScript client for CI/CD:

```typescript
import { test, expect } from "@playwright/test";
import { InboxedClient } from "inboxed";

const inboxed = new InboxedClient({
  apiUrl: "https://inboxed.notdefined.dev/api/v1",
  apiKey: process.env.INBOXED_API_KEY,
});

test("full signup + payment flow", async ({ page }) => {
  const testEmail = `test-${Date.now()}@mail.inboxed.dev`;

  // --- Signup with Cognito OTP ---
  await page.goto("https://myapp.dev/signup");
  await page.fill("[name=email]", testEmail);
  await page.click("#register");

  // Inboxed captures the OTP email from Cognito
  const otp = await inboxed.extractCode(testEmail, { timeout: 30_000 });
  expect(otp).toMatch(/^\d{6}$/);

  await page.fill("[name=otp]", otp);
  await page.click("#verify");
  await expect(page.locator("#dashboard")).toBeVisible();

  // --- Stripe Payment ---
  const endpoint = await inboxed.createEndpoint({ label: "stripe-test" });

  // Configure your app to use this endpoint for Stripe webhooks
  // (or pre-configure in Stripe dashboard)
  await page.goto("https://myapp.dev/checkout");
  await page.click("#pay-now");

  // ... complete Stripe checkout ...

  // Wait for Stripe's webhook to hit Inboxed
  const webhook = await inboxed.waitForRequest(endpoint.token, {
    timeout: 30_000,
  });

  expect(webhook.method).toBe("POST");
  expect(webhook.headers["stripe-signature"]).toBeDefined();

  const body = JSON.parse(webhook.body);
  expect(body.type).toBe("checkout.session.completed");
  expect(body.data.object.payment_status).toBe("paid");
});
```

---

## Phases Required

This test case exercises features across multiple development phases:

| Feature | Phase | Priority for this test |
|---------|-------|----------------------|
| SMTP server (capture emails) | Phase 1 | **Critical** |
| REST API (query emails) | Phase 2 | **Critical** |
| MCP server (extract OTP) | Phase 4 | **Critical** |
| TypeScript client library | Phase 5 | Nice to have |
| HTTP catcher (capture webhooks) | Phase 8 | **Critical** |
| Cloud deployment (inboxed.notdefined.dev) | Phase 9 | **Critical** |

**Minimum viable path:** Phases 1 → 2 → 4 → 8 → 9 (skip dashboard and testing helpers initially).

---

## Success Criteria

1. **OTP extraction works end-to-end:** Cognito sends email → Inboxed captures it → `extract_code` returns the 6-digit OTP within 5 seconds
2. **Webhook capture works end-to-end:** Stripe sends POST → Inboxed captures it → `wait_for_request` returns the full payload within 5 seconds
3. **MCP integration works:** Claude (browser extension) can call both `extract_code` and `wait_for_request` without leaving the automation context
4. **Cloud deployment accessible:** `inboxed.notdefined.dev` is reachable from both the app (SMTP) and Stripe (HTTPS)
5. **Single tool replaces two:** No need for Mailtrap + webhook.site — Inboxed handles both

---

## Open Questions

- [ ] Does Cognito support custom SMTP endpoints, or does it only send via SES? If SES-only, we need Inboxed's inbound email routing (Cloudflare Email Worker) to forward emails from SES to Inboxed.
- [ ] Should the HTTP catcher validate Stripe's webhook signature, or just capture the raw request and let the app validate?
- [ ] For the Cloud version, what are the rate limits for webhook endpoints? Stripe can send bursts during checkout.
- [ ] Can the MCP server connect to the Cloud instance remotely, or does it need to run alongside the API?
