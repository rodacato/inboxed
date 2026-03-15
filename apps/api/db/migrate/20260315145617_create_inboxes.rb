class CreateInboxes < ActiveRecord::Migration[8.1]
  def change
    create_table :inboxes, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true
      t.string :address, null: false
      t.integer :email_count, null: false, default: 0
      t.timestamps
    end

    add_index :inboxes, :address, unique: true
    add_index :inboxes, [:project_id, :created_at]
  end
end
