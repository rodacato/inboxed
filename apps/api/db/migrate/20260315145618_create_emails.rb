class CreateEmails < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :emails, id: :uuid do |t|
      t.references :inbox, type: :uuid, null: false, foreign_key: true
      t.string :from_address, null: false
      t.string :to_addresses, null: false, array: true, default: []
      t.string :cc_addresses, null: false, array: true, default: []
      t.string :subject
      t.text :body_html
      t.text :body_text
      t.jsonb :raw_headers, null: false, default: {}
      t.text :raw_source, null: false
      t.string :source_type, null: false, default: "relay"
      t.datetime :received_at, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :emails, [:inbox_id, :received_at]
    add_index :emails, :expires_at
    add_index :emails, :from_address
    execute <<-SQL
      CREATE INDEX idx_emails_fulltext ON emails
      USING gin(to_tsvector('simple', coalesce(subject, '') || ' ' || coalesce(body_text, '')))
    SQL
  end
end
