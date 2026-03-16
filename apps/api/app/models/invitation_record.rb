# frozen_string_literal: true

class InvitationRecord < ApplicationRecord
  self.table_name = "invitations"

  belongs_to :organization, class_name: "OrganizationRecord"
  belongs_to :invited_by, class_name: "UserRecord"

  validates :email, presence: true
  validates :token, presence: true, uniqueness: true
  validates :role, inclusion: {in: %w[org_admin member]}

  scope :pending, -> { where(accepted_at: nil).where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  def expired?
    expires_at <= Time.current
  end

  def accepted?
    accepted_at.present?
  end
end
