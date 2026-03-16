# frozen_string_literal: true

class CreateHttpRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :http_requests, id: :uuid do |t|
      t.references :http_endpoint, type: :uuid, null: false, foreign_key: true
      t.string :method, null: false
      t.string :path
      t.string :query_string
      t.jsonb :headers, null: false, default: {}
      t.text :body
      t.string :content_type
      t.string :ip_address
      t.integer :size_bytes, null: false, default: 0
      t.datetime :received_at, null: false
      t.datetime :expires_at
    end

    add_index :http_requests, [:http_endpoint_id, :received_at],
      order: {received_at: :desc}
    add_index :http_requests, :expires_at
  end
end
