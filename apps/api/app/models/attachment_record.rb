class AttachmentRecord < ApplicationRecord
  self.table_name = "attachments"

  belongs_to :email, class_name: "EmailRecord"
end
