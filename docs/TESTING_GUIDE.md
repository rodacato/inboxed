# Inboxed — Testing Guide

> How to test all features locally using `curl`, `swaks`, and plain SMTP commands.

---

## 1. Start the services

```bash
docker compose up -d
```

Wait for healthy status:

```bash
docker compose ps
```

Default ports:
| Service | Port |
|---------|------|
| API (Rails) | `3000` |
| SMTP | `2525` |
| Dashboard | `80` |
| MCP | `3001` |

---

## 2. Set variables

```bash
# Admin token (from .env)
ADMIN_TOKEN="changeme"
API=http://localhost:3000
```

---

## 3. Admin: Create a project + API key

### 3.1 Health check

```bash
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" $API/admin/status | jq
```

### 3.2 Create a project

```bash
curl -s -X POST $API/admin/projects \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "project": {
      "name": "My Test App",
      "slug": "my-test-app"
    }
  }' | jq

# Save the project ID
PROJECT_ID="<uuid-from-response>"
```

### 3.3 Issue an API key

```bash
curl -s -X POST $API/admin/projects/$PROJECT_ID/api_keys \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "api_key": { "label": "testing" }
  }' | jq

# ⚠️ Save the "token" — it's only shown once!
API_KEY="<token-from-response>"
```

### 3.4 List projects

```bash
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" $API/admin/projects | jq
```

### 3.5 Update a project

```bash
curl -s -X PATCH $API/admin/projects/$PROJECT_ID \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "project": {
      "name": "Renamed App",
      "default_ttl_hours": 48
    }
  }' | jq
```

### 3.6 List API keys

```bash
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  $API/admin/projects/$PROJECT_ID/api_keys | jq
```

---

## 4. Send test emails via SMTP

### Option A: Using `swaks` (recommended)

Install: `apt install swaks` / `brew install swaks`

```bash
# Simple text email
swaks \
  --to user@example.com \
  --from app@myapp.com \
  --server localhost:2525 \
  --auth PLAIN \
  --auth-user "$API_KEY" \
  --auth-password "$API_KEY" \
  --header "Subject: Welcome to Inboxed" \
  --body "Hello! This is a test email."

# HTML email
swaks \
  --to user@example.com \
  --from app@myapp.com \
  --server localhost:2525 \
  --auth PLAIN \
  --auth-user "$API_KEY" \
  --auth-password "$API_KEY" \
  --header "Subject: HTML Test" \
  --header "Content-Type: text/html" \
  --body "<h1>Hello!</h1><p>This is <b>HTML</b> content.</p>"

# Email with attachment
swaks \
  --to user@example.com \
  --from app@myapp.com \
  --server localhost:2525 \
  --auth PLAIN \
  --auth-user "$API_KEY" \
  --auth-password "$API_KEY" \
  --header "Subject: With Attachment" \
  --body "See attached." \
  --attach /path/to/file.pdf

# Multiple recipients (creates multiple inboxes)
swaks \
  --to alice@example.com,bob@example.com \
  --from app@myapp.com \
  --server localhost:2525 \
  --auth PLAIN \
  --auth-user "$API_KEY" \
  --auth-password "$API_KEY" \
  --header "Subject: Team Notification" \
  --body "Hello team!"
```

### Option B: Using `curl` with SMTP protocol

```bash
curl --url "smtp://localhost:2525" \
  --user "$API_KEY:$API_KEY" \
  --mail-from "app@myapp.com" \
  --mail-rcpt "user@example.com" \
  -T - <<EOF
From: app@myapp.com
To: user@example.com
Subject: Curl SMTP Test
Content-Type: text/plain

This email was sent via curl SMTP.
EOF
```

### Option C: Using Python (no extra deps)

```python
import smtplib
from email.mime.text import MIMEText

API_KEY = "<your-api-key>"

msg = MIMEText("Hello from Python!")
msg["Subject"] = "Python Test Email"
msg["From"] = "app@myapp.com"
msg["To"] = "user@example.com"

with smtplib.SMTP("localhost", 2525) as s:
    s.login(API_KEY, API_KEY)
    s.send_message(msg)
    print("Sent!")
```

### Option D: Using Ruby

```ruby
require "net/smtp"

api_key = "<your-api-key>"
message = <<~MSG
  From: app@myapp.com
  To: user@example.com
  Subject: Ruby Test

  Hello from Ruby!
MSG

Net::SMTP.start("localhost", 2525) do |smtp|
  smtp.authenticate(:plain, api_key, api_key)
  smtp.send_message(message, "app@myapp.com", "user@example.com"
end
```

### Option E: Raw telnet/netcat (for protocol debugging)

```bash
# See the full SMTP handshake
(
echo "EHLO test"
sleep 0.5
echo "AUTH PLAIN $(echo -ne "\0$API_KEY\0$API_KEY" | base64)"
sleep 0.5
echo "MAIL FROM:<app@myapp.com>"
sleep 0.3
echo "RCPT TO:<user@example.com>"
sleep 0.3
echo "DATA"
sleep 0.3
echo "Subject: Telnet Test"
echo "From: app@myapp.com"
echo "To: user@example.com"
echo ""
echo "Raw SMTP test body"
echo "."
sleep 0.3
echo "QUIT"
) | nc localhost 2525
```

---

## 5. Query emails via REST API (v1)

### 5.1 API status

```bash
curl -s -H "Authorization: Bearer $API_KEY" $API/api/v1/status | jq
```

### 5.2 List inboxes

```bash
curl -s -H "Authorization: Bearer $API_KEY" $API/api/v1/inboxes | jq
```

Inboxes are created automatically when emails arrive. Save an inbox ID:

```bash
INBOX_ID="<uuid-from-response>"
```

### 5.3 List emails in an inbox

```bash
curl -s -H "Authorization: Bearer $API_KEY" \
  "$API/api/v1/inboxes/$INBOX_ID/emails?limit=5" | jq
```

### 5.4 Get full email detail

```bash
EMAIL_ID="<uuid-from-email-list>"

curl -s -H "Authorization: Bearer $API_KEY" \
  $API/api/v1/emails/$EMAIL_ID | jq
```

### 5.5 Get raw MIME source

```bash
curl -s -H "Authorization: Bearer $API_KEY" \
  $API/api/v1/emails/$EMAIL_ID/raw
```

### 5.6 List attachments

```bash
curl -s -H "Authorization: Bearer $API_KEY" \
  $API/api/v1/emails/$EMAIL_ID/attachments | jq
```

### 5.7 Download an attachment

```bash
ATTACHMENT_ID="<uuid>"

curl -s -H "Authorization: Bearer $API_KEY" \
  $API/api/v1/attachments/$ATTACHMENT_ID/download \
  -o downloaded_file.pdf
```

### 5.8 Full-text search

```bash
# Search across all emails in the project
curl -s -H "Authorization: Bearer $API_KEY" \
  "$API/api/v1/search?q=welcome&limit=10" | jq
```

### 5.9 Wait for an email (long-poll)

This is powerful for automation — send an email, then wait for it to arrive:

```bash
# Terminal 1: wait for the email (blocks up to 30s)
curl -s -X POST $API/api/v1/emails/wait \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "inbox_address": "otp@example.com",
    "subject_pattern": "verification",
    "timeout_seconds": 30
  }' | jq

# Terminal 2: send the email (while Terminal 1 is waiting)
swaks \
  --to otp@example.com \
  --from auth@myapp.com \
  --server localhost:2525 \
  --auth PLAIN \
  --auth-user "$API_KEY" \
  --auth-password "$API_KEY" \
  --header "Subject: Your verification code" \
  --body "Your OTP is: 847291"
```

---

## 6. Admin: Manage inboxes & emails

### 6.1 List inboxes for a project

```bash
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  $API/admin/projects/$PROJECT_ID/inboxes | jq
```

### 6.2 Purge all emails in an inbox (keep inbox)

```bash
curl -s -X DELETE -H "Authorization: Bearer $ADMIN_TOKEN" \
  $API/admin/projects/$PROJECT_ID/inboxes/$INBOX_ID/emails | jq
```

### 6.3 Delete an inbox entirely

```bash
curl -s -X DELETE -H "Authorization: Bearer $ADMIN_TOKEN" \
  $API/admin/projects/$PROJECT_ID/inboxes/$INBOX_ID
```

### 6.4 Delete a single email

```bash
curl -s -X DELETE -H "Authorization: Bearer $ADMIN_TOKEN" \
  $API/admin/emails/$EMAIL_ID
```

### 6.5 Admin search (across all projects)

```bash
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$API/admin/search?q=password+reset" | jq
```

---

## 7. Complete end-to-end test script

Copy-paste this entire block to run a full test:

```bash
#!/usr/bin/env bash
set -euo pipefail

API=http://localhost:3000
ADMIN_TOKEN="changeme"

echo "=== 1. Health check ==="
curl -sf -H "Authorization: Bearer $ADMIN_TOKEN" $API/admin/status | jq .status

echo -e "\n=== 2. Create project ==="
PROJECT=$(curl -sf -X POST $API/admin/projects \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"project":{"name":"E2E Test","slug":"e2e-test"}}')
PROJECT_ID=$(echo "$PROJECT" | jq -r '.id')
echo "Project: $PROJECT_ID"

echo -e "\n=== 3. Issue API key ==="
KEY_RESPONSE=$(curl -sf -X POST $API/admin/projects/$PROJECT_ID/api_keys \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"api_key":{"label":"e2e"}}')
API_KEY=$(echo "$KEY_RESPONSE" | jq -r '.token')
echo "API Key: ${API_KEY:0:8}..."

echo -e "\n=== 4. Send test email via SMTP ==="
swaks --to test@e2e.local \
  --from ci@myapp.com \
  --server localhost:2525 \
  --auth PLAIN \
  --auth-user "$API_KEY" \
  --auth-password "$API_KEY" \
  --header "Subject: E2E Test $(date +%s)" \
  --body "Automated end-to-end test email" \
  --quiet

echo "Email sent!"

echo -e "\n=== 5. Wait 2s for processing ==="
sleep 2

echo -e "\n=== 6. List inboxes ==="
INBOXES=$(curl -sf -H "Authorization: Bearer $API_KEY" $API/api/v1/inboxes)
echo "$INBOXES" | jq '.data[] | {id, address, email_count}'
INBOX_ID=$(echo "$INBOXES" | jq -r '.data[0].id')

echo -e "\n=== 7. List emails ==="
EMAILS=$(curl -sf -H "Authorization: Bearer $API_KEY" \
  "$API/api/v1/inboxes/$INBOX_ID/emails")
echo "$EMAILS" | jq '.data[] | {id, from, subject, received_at}'
EMAIL_ID=$(echo "$EMAILS" | jq -r '.data[0].id')

echo -e "\n=== 8. Get email detail ==="
curl -sf -H "Authorization: Bearer $API_KEY" \
  $API/api/v1/emails/$EMAIL_ID | jq '{from, to, subject, body_text}'

echo -e "\n=== 9. Search ==="
curl -sf -H "Authorization: Bearer $API_KEY" \
  "$API/api/v1/search?q=end-to-end" | jq '.data | length'

echo -e "\n=== 10. Cleanup ==="
curl -sf -X DELETE -H "Authorization: Bearer $ADMIN_TOKEN" \
  $API/admin/projects/$PROJECT_ID
echo "Project deleted."

echo -e "\n✅ All tests passed!"
```

---

## 8. Simulate real-world scenarios

### Password reset flow

```bash
# Your app sends a password reset email
swaks --to user@example.com --from noreply@myapp.com \
  --server localhost:2525 --auth PLAIN \
  --auth-user "$API_KEY" --auth-password "$API_KEY" \
  --header "Subject: Reset your password" \
  --body "Click here to reset: https://myapp.com/reset?token=abc123"

# Your test extracts the link
EMAIL=$(curl -s -H "Authorization: Bearer $API_KEY" \
  -X POST $API/api/v1/emails/wait \
  -H "Content-Type: application/json" \
  -d '{"inbox_address":"user@example.com","subject_pattern":"Reset"}')

echo "$EMAIL" | jq -r '.body_text' | grep -oP 'https://\S+'
```

### OTP verification

```bash
# App sends OTP
swaks --to verify@test.local --from auth@myapp.com \
  --server localhost:2525 --auth PLAIN \
  --auth-user "$API_KEY" --auth-password "$API_KEY" \
  --header "Subject: Your code is 847291" \
  --body "Your verification code: 847291"

# Extract OTP from subject
EMAIL=$(curl -s -H "Authorization: Bearer $API_KEY" \
  -X POST $API/api/v1/emails/wait \
  -H "Content-Type: application/json" \
  -d '{"inbox_address":"verify@test.local","subject_pattern":"code"}')

echo "$EMAIL" | jq -r '.subject' | grep -oP '\d{6}'
```

### Bulk send for load testing

```bash
for i in $(seq 1 50); do
  swaks --to "user-$i@loadtest.local" \
    --from "sender@myapp.com" \
    --server localhost:2525 --auth PLAIN \
    --auth-user "$API_KEY" --auth-password "$API_KEY" \
    --header "Subject: Load test #$i" \
    --body "Email number $i" \
    --quiet &
done
wait
echo "50 emails sent"
```

---

## 9. Pagination

```bash
# First page
RESPONSE=$(curl -s -H "Authorization: Bearer $API_KEY" \
  "$API/api/v1/inboxes?limit=2")
echo "$RESPONSE" | jq '.pagination'

# Next page using cursor
CURSOR=$(echo "$RESPONSE" | jq -r '.pagination.next_cursor')
curl -s -H "Authorization: Bearer $API_KEY" \
  "$API/api/v1/inboxes?limit=2&after=$CURSOR" | jq
```

---

## 10. Error cases to verify

```bash
# No auth header → 401
curl -s $API/api/v1/inboxes | jq

# Invalid token → 401
curl -s -H "Authorization: Bearer invalid" $API/api/v1/inboxes | jq

# Non-existent resource → 404
curl -s -H "Authorization: Bearer $API_KEY" \
  $API/api/v1/emails/00000000-0000-0000-0000-000000000000 | jq

# Invalid project params → 422
curl -s -X POST $API/admin/projects \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"project":{}}' | jq

# Duplicate slug → 422
curl -s -X POST $API/admin/projects \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"project":{"name":"Dup","slug":"e2e-test"}}' | jq
```

---

## Quick reference

| What | Command |
|------|---------|
| Start services | `docker compose up -d` |
| View logs | `docker compose logs -f api` |
| SMTP logs | `docker compose logs -f api \| grep smtp` |
| Rails console | `docker compose exec api bin/rails console` |
| DB console | `docker compose exec db psql -U inboxed inboxed_production` |
| Stop all | `docker compose down` |
| Reset data | `docker compose down -v` (deletes volumes) |
