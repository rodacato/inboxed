class ProjectRecord < ApplicationRecord
  self.table_name = "projects"

  has_many :api_keys, class_name: "ApiKeyRecord", foreign_key: :project_id, dependent: :destroy
  has_many :inboxes, class_name: "InboxRecord", foreign_key: :project_id, dependent: :destroy
end
