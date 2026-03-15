class CreateWebhookDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_deliveries, id: :uuid do |t|
      t.references :webhook_endpoint, type: :uuid, null: false, foreign_key: true
      t.string :event_type, null: false
      t.string :event_id, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :status, null: false, default: "pending"
      t.integer :http_status
      t.text :response_body
      t.integer :attempt_count, null: false, default: 0
      t.datetime :last_attempted_at
      t.datetime :next_retry_at
      t.datetime :created_at, null: false
    end

    add_index :webhook_deliveries, [:webhook_endpoint_id, :status]
    add_index :webhook_deliveries, [:webhook_endpoint_id, :created_at]
    add_index :webhook_deliveries, [:status, :next_retry_at]
  end
end
