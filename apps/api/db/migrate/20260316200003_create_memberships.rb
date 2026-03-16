# frozen_string_literal: true

class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: {to_table: :users, on_delete: :cascade}
      t.references :organization, type: :uuid, null: false, foreign_key: {to_table: :organizations, on_delete: :cascade}
      t.string :role, null: false, default: "member"

      t.timestamp :created_at, null: false, default: -> { "NOW()" }
    end

    add_index :memberships, [:user_id, :organization_id], unique: true
    add_check_constraint :memberships, "role IN ('org_admin', 'member')", name: "memberships_role_check"
  end
end
