# frozen_string_literal: true

class ProjectRecord < ApplicationRecord
  self.table_name = "projects"

  belongs_to :organization, class_name: "OrganizationRecord", optional: true

  has_many :api_keys, class_name: "ApiKeyRecord", foreign_key: :project_id, dependent: :destroy
  has_many :inboxes, class_name: "InboxRecord", foreign_key: :project_id, dependent: :destroy
  has_many :http_endpoints, class_name: "HttpEndpointRecord", foreign_key: :project_id, dependent: :destroy
  has_many :emails, through: :inboxes, source: :emails, class_name: "EmailRecord"
end
