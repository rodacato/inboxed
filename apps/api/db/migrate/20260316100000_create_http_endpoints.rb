# frozen_string_literal: true

class CreateHttpEndpoints < ActiveRecord::Migration[8.1]
  def change
    create_table :http_endpoints, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true
      t.string :endpoint_type, null: false # webhook, form, heartbeat
      t.string :token, null: false
      t.string :label
      t.string :description
      t.string :allowed_methods, array: true, null: false, default: ["POST"]
      t.string :allowed_ips, array: true, null: false, default: []
      t.integer :max_body_bytes, null: false, default: 262_144 # 256 KB
      t.integer :request_count, null: false, default: 0

      # Form-specific columns
      t.string :response_mode, default: "json" # json, redirect, html
      t.string :response_redirect_url
      t.text :response_html

      # Heartbeat-specific columns
      t.integer :expected_interval_seconds
      t.string :heartbeat_status, default: "pending" # pending, healthy, late, down
      t.datetime :last_ping_at
      t.datetime :status_changed_at

      t.timestamps
    end

    add_index :http_endpoints, :token, unique: true
    add_index :http_endpoints, [:project_id, :endpoint_type]
    add_index :http_endpoints, [:endpoint_type, :heartbeat_status],
      name: "index_http_endpoints_on_heartbeat_lookup"
  end
end
