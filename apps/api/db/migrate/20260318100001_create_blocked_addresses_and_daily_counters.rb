# frozen_string_literal: true

class CreateBlockedAddressesAndDailyCounters < ActiveRecord::Migration[8.1]
  def change
    create_table :blocked_addresses, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :address, null: false
      t.string :reason
      t.uuid :blocked_by_id
      t.timestamps
    end

    add_index :blocked_addresses, :address, unique: true

    create_table :daily_usage_counters, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :organization_id, null: false
      t.date :date, null: false
      t.integer :emails_count, default: 0, null: false
      t.integer :requests_count, default: 0, null: false
    end

    add_index :daily_usage_counters, [:organization_id, :date], unique: true, name: "idx_daily_counters_org_date"
    add_foreign_key :daily_usage_counters, :organizations, on_delete: :cascade
  end
end
