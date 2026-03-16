# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.boolean :site_admin, default: false
      t.string :github_uid
      t.string :github_username
      t.timestamptz :verified_at
      t.string :verification_token
      t.timestamptz :verification_sent_at
      t.string :password_reset_token
      t.timestamptz :password_reset_sent_at
      t.timestamptz :last_sign_in_at
      t.integer :sign_in_count, default: 0, null: false

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :verification_token, unique: true, where: "verification_token IS NOT NULL"
    add_index :users, :password_reset_token, unique: true, where: "password_reset_token IS NOT NULL"
    add_index :users, :github_uid, unique: true, where: "github_uid IS NOT NULL"
  end
end
