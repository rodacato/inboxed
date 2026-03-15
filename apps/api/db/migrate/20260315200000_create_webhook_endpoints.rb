class CreateWebhookEndpoints < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_endpoints, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true
      t.string :url, null: false
      t.string :event_types, array: true, null: false, default: []
      t.string :status, null: false, default: "active"
      t.string :secret, null: false
      t.string :description
      t.integer :failure_count, null: false, default: 0
      t.timestamps
    end

    add_index :webhook_endpoints, [:project_id, :status]
  end
end
