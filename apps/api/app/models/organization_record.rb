# frozen_string_literal: true

class OrganizationRecord < ApplicationRecord
  self.table_name = "organizations"

  has_many :memberships, class_name: "MembershipRecord", foreign_key: :organization_id, dependent: :destroy
  has_many :users, through: :memberships, source: :user, class_name: "UserRecord"
  has_many :projects, class_name: "ProjectRecord", foreign_key: :organization_id, dependent: :destroy
  has_many :invitations, class_name: "InvitationRecord", foreign_key: :organization_id, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  def trial?
    trial_ends_at.present?
  end

  def trial_active?
    trial? && trial_ends_at > Time.current
  end

  def trial_expired?
    trial? && trial_ends_at <= Time.current
  end

  def permanent?
    trial_ends_at.nil?
  end

  def active?
    permanent? || trial_active?
  end

  def days_remaining
    return nil unless trial?
    [(trial_ends_at - Time.current).to_i / 1.day, 0].max
  end
end
