# frozen_string_literal: true

class MembershipRecord < ApplicationRecord
  self.table_name = "memberships"

  belongs_to :user, class_name: "UserRecord"
  belongs_to :organization, class_name: "OrganizationRecord"

  validates :role, inclusion: {in: %w[org_admin member]}
end
