# ADR-006: Store Attachments in PostgreSQL

**Status:** accepted
**Date:** 2026-03-15
**Deciders:** Project owner

## Context

Inboxed receives emails via SMTP that may contain attachments (PDFs, images, inline images). These attachments need to be stored and retrievable via the REST API and MCP server.

The question is where to store the binary content of attachments.

## Options

### A: PostgreSQL `bytea` column

Store attachment content directly in the emails database as a `bytea` column on the `attachments` table.

- **Pro:** Single system to backup, query, and manage. Transactional consistency with the email record. No additional infrastructure.
- **Pro:** Attachment deletion is automatic with email deletion (FK cascade or explicit delete).
- **Con:** Large attachments increase database size and backup time.
- **Con:** PostgreSQL is not optimized for serving large binary blobs — adds memory pressure during queries.

### B: Filesystem / object storage (S3, MinIO)

Store attachment content on disk or in an object store, with a reference path in the database.

- **Pro:** Optimized for large binary content. Cheap storage.
- **Con:** Additional infrastructure to manage (filesystem permissions, object store credentials, cleanup on email deletion).
- **Con:** No transactional consistency — email could be persisted but attachment upload fails.
- **Con:** Self-hosting becomes more complex (another service to configure).

### C: Active Storage

Use Rails Active Storage with a local disk or S3 backend.

- **Pro:** Rails-native, familiar API.
- **Con:** Active Storage was skipped in the Rails setup (`--skip-active-storage`) per spec 000. Adding it now introduces blobs/attachments tables and service dependencies.
- **Con:** Overkill for this use case — we don't need variants, direct uploads, or mirrors.

## Decision

**Option A — PostgreSQL `bytea` column.**

Inboxed is a **development and testing tool**, not a production email server. The expected volume is low (tens to hundreds of emails per day, not millions). Attachments in test emails are typically small (logos, PDFs, screenshots).

The `SMTP_MAX_MESSAGE_SIZE` limit (default 3MB, configurable via env var) caps the total MIME message size, which naturally limits attachment sizes. For a self-hosted dev tool processing test emails with small attachments, the simplicity of a single PostgreSQL database outweighs the performance benefits of object storage.

## Consequences

- Attachment content stored in `attachments.content` as `bytea`
- Database backups include all attachment data — larger but complete
- No additional infrastructure for self-hosting
- If a future user has high-volume needs with large attachments, we can add an object storage adapter behind the repository pattern without changing the domain layer
- `SMTP_MAX_MESSAGE_SIZE` env var (default 3MB) provides a safety valve — configurable per deployment

## Revisit When

- Users report database size issues due to attachment volume
- A deployment target requires object storage (e.g., managed PostgreSQL with limited storage)
- Inboxed is used in high-volume load testing scenarios (Phase 7)
