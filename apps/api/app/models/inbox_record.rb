class InboxRecord < ApplicationRecord
  self.table_name = "inboxes"

  belongs_to :project, class_name: "ProjectRecord"
  has_many :emails, class_name: "EmailRecord", foreign_key: :inbox_id, dependent: :destroy
end
