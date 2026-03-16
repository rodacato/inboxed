# frozen_string_literal: true

class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations, id: :uuid do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: {on_delete: :cascade}
      t.string :email, null: false
      t.string :role, null: false, default: "member"
      t.string :token, null: false
      t.references :invited_by, type: :uuid, null: false, foreign_key: {to_table: :users}
      t.timestamptz :accepted_at
      t.timestamptz :expires_at, null: false

      t.timestamp :created_at, null: false, default: -> { "NOW()" }
    end

    add_index :invitations, :token, unique: true
    add_index :invitations, [:organization_id, :email]
    add_check_constraint :invitations, "role IN ('org_admin', 'member')", name: "invitations_role_check"
  end
end
