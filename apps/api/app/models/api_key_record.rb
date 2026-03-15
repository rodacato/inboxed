class ApiKeyRecord < ApplicationRecord
  self.table_name = "api_keys"

  belongs_to :project, class_name: "ProjectRecord"
end
