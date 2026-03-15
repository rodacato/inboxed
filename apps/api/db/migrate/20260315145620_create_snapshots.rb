class CreateSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :snapshots do |t|
      t.string :stream_name, null: false
      t.integer :stream_position, null: false
      t.string :aggregate_type, null: false
      t.integer :schema_version, null: false, default: 1
      t.jsonb :state, null: false
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :snapshots, :stream_name, unique: true
  end
end
