# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_17_100001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "api_keys", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "label"
    t.datetime "last_used_at"
    t.uuid "project_id", null: false
    t.string "token_digest", null: false
    t.string "token_prefix", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_api_keys_on_project_id"
    t.index ["token_prefix"], name: "index_api_keys_on_token_prefix"
  end

  create_table "attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.binary "content", null: false
    t.string "content_id"
    t.string "content_type", null: false
    t.datetime "created_at", null: false
    t.uuid "email_id", null: false
    t.string "filename", null: false
    t.boolean "inline", default: false, null: false
    t.integer "size_bytes", null: false
    t.datetime "updated_at", null: false
    t.index ["email_id"], name: "index_attachments_on_email_id"
  end

  create_table "emails", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "body_html"
    t.text "body_text"
    t.string "cc_addresses", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "from_address", null: false
    t.uuid "inbox_id", null: false
    t.jsonb "raw_headers", default: {}, null: false
    t.text "raw_source", null: false
    t.datetime "received_at", null: false
    t.string "source_type", default: "relay", null: false
    t.string "subject"
    t.string "to_addresses", default: [], null: false, array: true
    t.datetime "updated_at", null: false
    t.index "to_tsvector('simple'::regconfig, (((COALESCE(subject, ''::character varying))::text || ' '::text) || COALESCE(body_text, ''::text)))", name: "idx_emails_fulltext", using: :gin
    t.index ["expires_at"], name: "index_emails_on_expires_at"
    t.index ["from_address"], name: "index_emails_on_from_address"
    t.index ["inbox_id", "received_at"], name: "index_emails_on_inbox_id_and_received_at"
    t.index ["inbox_id"], name: "index_emails_on_inbox_id"
  end

  create_table "events", force: :cascade do |t|
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.jsonb "data", default: {}, null: false
    t.string "event_type", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "stream_name", null: false
    t.integer "stream_position", null: false
    t.index "((metadata ->> 'causation_id'::text))", name: "idx_events_causation_id"
    t.index "((metadata ->> 'correlation_id'::text))", name: "idx_events_correlation_id"
    t.index ["created_at"], name: "index_events_on_created_at"
    t.index ["event_type"], name: "index_events_on_event_type"
    t.index ["stream_name", "stream_position"], name: "index_events_on_stream_name_and_stream_position", unique: true
  end

  create_table "http_endpoints", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "allowed_ips", default: [], null: false, array: true
    t.string "allowed_methods", default: ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"], null: false, array: true
    t.datetime "created_at", null: false
    t.string "description"
    t.string "endpoint_type", null: false
    t.integer "expected_interval_seconds"
    t.string "heartbeat_status", default: "pending"
    t.string "label"
    t.datetime "last_ping_at"
    t.integer "max_body_bytes", default: 262144, null: false
    t.uuid "project_id", null: false
    t.integer "request_count", default: 0, null: false
    t.text "response_html"
    t.string "response_mode", default: "json"
    t.string "response_redirect_url"
    t.datetime "status_changed_at"
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint_type", "heartbeat_status"], name: "index_http_endpoints_on_heartbeat_lookup"
    t.index ["project_id", "endpoint_type"], name: "index_http_endpoints_on_project_id_and_endpoint_type"
    t.index ["project_id"], name: "index_http_endpoints_on_project_id"
    t.index ["token"], name: "index_http_endpoints_on_token", unique: true
  end

  create_table "http_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "body"
    t.string "content_type"
    t.datetime "expires_at"
    t.jsonb "headers", default: {}, null: false
    t.uuid "http_endpoint_id", null: false
    t.string "ip_address"
    t.string "method", null: false
    t.string "path"
    t.string "query_string"
    t.datetime "received_at", null: false
    t.integer "size_bytes", default: 0, null: false
    t.index ["expires_at"], name: "index_http_requests_on_expires_at"
    t.index ["http_endpoint_id", "received_at"], name: "index_http_requests_on_http_endpoint_id_and_received_at", order: { received_at: :desc }
    t.index ["http_endpoint_id"], name: "index_http_requests_on_http_endpoint_id"
  end

  create_table "inboxes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "address", null: false
    t.datetime "created_at", null: false
    t.integer "email_count", default: 0, null: false
    t.uuid "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["address"], name: "index_inboxes_on_address"
    t.index ["project_id", "address"], name: "index_inboxes_on_project_id_and_address", unique: true
    t.index ["project_id", "created_at"], name: "index_inboxes_on_project_id_and_created_at"
    t.index ["project_id"], name: "index_inboxes_on_project_id"
  end

  create_table "invitations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.timestamptz "accepted_at"
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false
    t.string "email", null: false
    t.timestamptz "expires_at", null: false
    t.uuid "invited_by_id", null: false
    t.uuid "organization_id", null: false
    t.string "role", default: "member", null: false
    t.string "token", null: false
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["organization_id", "email"], name: "index_invitations_on_organization_id_and_email"
    t.index ["organization_id"], name: "index_invitations_on_organization_id"
    t.index ["token"], name: "index_invitations_on_token", unique: true
    t.check_constraint "role::text = ANY (ARRAY['org_admin'::character varying, 'member'::character varying]::text[])", name: "invitations_role_check"
  end

  create_table "memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false
    t.uuid "organization_id", null: false
    t.string "role", default: "member", null: false
    t.uuid "user_id", null: false
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
    t.index ["user_id", "organization_id"], name: "index_memberships_on_user_id_and_organization_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.check_constraint "role::text = ANY (ARRAY['org_admin'::character varying, 'member'::character varying]::text[])", name: "memberships_role_check"
  end

  create_table "organizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.jsonb "settings", default: {}, null: false
    t.string "slug", null: false
    t.timestamptz "trial_ends_at"
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "projects", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "default_ttl_hours"
    t.integer "max_inbox_count", default: 100, null: false
    t.string "name", null: false
    t.uuid "organization_id"
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "idx_projects_organization"
    t.index ["organization_id"], name: "index_projects_on_organization_id"
    t.index ["slug"], name: "index_projects_on_slug", unique: true
  end

  create_table "sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "data"
    t.string "session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.text "value"
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "snapshots", force: :cascade do |t|
    t.string "aggregate_type", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "schema_version", default: 1, null: false
    t.jsonb "state", null: false
    t.string "stream_name", null: false
    t.integer "stream_position", null: false
    t.index ["stream_name"], name: "index_snapshots_on_stream_name", unique: true
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "github_uid"
    t.string "github_username"
    t.timestamptz "last_sign_in_at"
    t.string "password_digest", null: false
    t.timestamptz "password_reset_sent_at"
    t.string "password_reset_token"
    t.integer "sign_in_count", default: 0, null: false
    t.boolean "site_admin", default: false
    t.datetime "updated_at", null: false
    t.timestamptz "verification_sent_at"
    t.string "verification_token"
    t.timestamptz "verified_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["github_uid"], name: "index_users_on_github_uid", unique: true, where: "(github_uid IS NOT NULL)"
    t.index ["password_reset_token"], name: "index_users_on_password_reset_token", unique: true, where: "(password_reset_token IS NOT NULL)"
    t.index ["verification_token"], name: "index_users_on_verification_token", unique: true, where: "(verification_token IS NOT NULL)"
  end

  create_table "webhook_deliveries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "attempt_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "event_id", null: false
    t.string "event_type", null: false
    t.integer "http_status"
    t.datetime "last_attempted_at"
    t.datetime "next_retry_at"
    t.jsonb "payload", default: {}, null: false
    t.text "response_body"
    t.string "status", default: "pending", null: false
    t.uuid "webhook_endpoint_id", null: false
    t.index ["status", "next_retry_at"], name: "index_webhook_deliveries_on_status_and_next_retry_at"
    t.index ["webhook_endpoint_id", "created_at"], name: "index_webhook_deliveries_on_webhook_endpoint_id_and_created_at"
    t.index ["webhook_endpoint_id", "status"], name: "index_webhook_deliveries_on_webhook_endpoint_id_and_status"
    t.index ["webhook_endpoint_id"], name: "index_webhook_deliveries_on_webhook_endpoint_id"
  end

  create_table "webhook_endpoints", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "event_types", default: [], null: false, array: true
    t.integer "failure_count", default: 0, null: false
    t.uuid "project_id", null: false
    t.string "secret", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["project_id", "status"], name: "index_webhook_endpoints_on_project_id_and_status"
    t.index ["project_id"], name: "index_webhook_endpoints_on_project_id"
  end

  add_foreign_key "api_keys", "projects"
  add_foreign_key "attachments", "emails"
  add_foreign_key "emails", "inboxes"
  add_foreign_key "http_endpoints", "projects"
  add_foreign_key "http_requests", "http_endpoints"
  add_foreign_key "inboxes", "projects"
  add_foreign_key "invitations", "organizations", on_delete: :cascade
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "memberships", "organizations", on_delete: :cascade
  add_foreign_key "memberships", "users", on_delete: :cascade
  add_foreign_key "projects", "organizations", on_delete: :cascade
  add_foreign_key "webhook_deliveries", "webhook_endpoints"
  add_foreign_key "webhook_endpoints", "projects"
end
