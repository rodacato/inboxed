class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :default_ttl_hours
      t.integer :max_inbox_count, null: false, default: 100
      t.timestamps
    end

    add_index :projects, :slug, unique: true
  end
end
