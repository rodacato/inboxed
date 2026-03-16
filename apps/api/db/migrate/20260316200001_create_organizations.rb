# frozen_string_literal: true

class CreateOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamptz :trial_ends_at
      t.jsonb :settings, null: false, default: {}

      t.timestamps
    end

    add_index :organizations, :slug, unique: true
  end
end
