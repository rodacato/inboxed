# frozen_string_literal: true

class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings, id: :uuid do |t|
      t.string :key, null: false
      t.text :value
    end

    add_index :settings, :key, unique: true
  end
end
