class CreateAttachments < ActiveRecord::Migration[8.1]
  def change
    create_table :attachments, id: :uuid do |t|
      t.references :email, type: :uuid, null: false, foreign_key: true
      t.string :filename, null: false
      t.string :content_type, null: false
      t.integer :size_bytes, null: false
      t.binary :content, null: false
      t.string :content_id
      t.boolean :inline, null: false, default: false
      t.timestamps
    end
  end
end
