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

ActiveRecord::Schema[8.1].define(version: 2026_03_15_134557) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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
end
