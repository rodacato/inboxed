class EmailRecord < ApplicationRecord
  self.table_name = "emails"

  belongs_to :inbox, class_name: "InboxRecord"
  has_many :attachments, class_name: "AttachmentRecord", foreign_key: :email_id, dependent: :destroy

  scope :expired, -> { where("expires_at < ?", Time.current) }
end
