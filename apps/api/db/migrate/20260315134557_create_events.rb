# frozen_string_literal: true

class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.string :stream_name, null: false
      t.integer :stream_position, null: false
      t.string :event_type, null: false
      t.jsonb :data, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :events, [:stream_name, :stream_position], unique: true
    add_index :events, :event_type
    add_index :events, :created_at
    add_index :events, "(metadata->>'correlation_id')", name: "idx_events_correlation_id", using: :btree
    add_index :events, "(metadata->>'causation_id')", name: "idx_events_causation_id", using: :btree
  end
end
