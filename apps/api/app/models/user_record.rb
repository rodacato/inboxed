# frozen_string_literal: true

class UserRecord < ApplicationRecord
  self.table_name = "users"

  has_secure_password

  has_many :memberships, class_name: "MembershipRecord", foreign_key: :user_id, dependent: :destroy
  has_many :organizations, through: :memberships, source: :organization, class_name: "OrganizationRecord"

  validates :email, presence: true, uniqueness: true, format: {with: URI::MailTo::EMAIL_REGEXP}
  validates :password, length: {minimum: 8}, on: :create

  scope :verified, -> { where.not(verified_at: nil) }
  scope :unverified, -> { where(verified_at: nil) }

  def organization
    organizations.first
  end

  def role_in(org)
    return "site_admin" if site_admin?
    memberships.find_by(organization: org)&.role || "member"
  end

  def site_admin?
    site_admin
  end

  def verified?
    verified_at.present?
  end
end
