# frozen_string_literal: true

class ChangeInboxAddressUniqueness < ActiveRecord::Migration[8.1]
  def change
    remove_index :inboxes, :address
    add_index :inboxes, [:project_id, :address], unique: true
    add_index :inboxes, :address
  end
end
