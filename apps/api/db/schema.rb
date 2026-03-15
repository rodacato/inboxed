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

ActiveRecord::Schema[8.1].define(version: 2026_03_15_145620) do
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

  create_table "inboxes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "address", null: false
    t.datetime "created_at", null: false
    t.integer "email_count", default: 0, null: false
    t.uuid "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["address"], name: "index_inboxes_on_address", unique: true
    t.index ["project_id", "created_at"], name: "index_inboxes_on_project_id_and_created_at"
    t.index ["project_id"], name: "index_inboxes_on_project_id"
  end

  create_table "projects", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "default_ttl_hours"
    t.integer "max_inbox_count", default: 100, null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_projects_on_slug", unique: true
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

  add_foreign_key "api_keys", "projects"
  add_foreign_key "attachments", "emails"
  add_foreign_key "emails", "inboxes"
  add_foreign_key "inboxes", "projects"
end
