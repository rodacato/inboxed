# frozen_string_literal: true

class OrganizationRecord < ApplicationRecord
  self.table_name = "organizations"

  # Default plan limits for trial organizations (overridable via settings JSONB)
  DEFAULT_PLAN_LIMITS = {
    "max_inboxes" => 3,
    "max_endpoints" => 3,
    "max_emails_per_day" => 100,
    "max_requests_per_day" => 200
  }.freeze

  has_many :memberships, class_name: "MembershipRecord", foreign_key: :organization_id, dependent: :destroy
  has_many :users, through: :memberships, source: :user, class_name: "UserRecord"
  has_many :projects, class_name: "ProjectRecord", foreign_key: :organization_id, dependent: :destroy
  has_many :invitations, class_name: "InvitationRecord", foreign_key: :organization_id, dependent: :destroy
  has_many :daily_usage_counters, class_name: "DailyUsageCounterRecord", foreign_key: :organization_id, dependent: :destroy

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

  # Plan limits — permanent orgs have no limits, trial orgs use defaults (overridable via settings)
  def plan_limits
    return nil if permanent?
    DEFAULT_PLAN_LIMITS.merge(settings.fetch("plan_limits", {}))
  end

  def max_inboxes
    plan_limits&.fetch("max_inboxes", nil)
  end

  def max_endpoints
    plan_limits&.fetch("max_endpoints", nil)
  end

  def max_emails_per_day
    plan_limits&.fetch("max_emails_per_day", nil)
  end

  def max_requests_per_day
    plan_limits&.fetch("max_requests_per_day", nil)
  end

  def total_inbox_count
    projects.joins("INNER JOIN inboxes ON inboxes.project_id = projects.id").count
  end

  def total_endpoint_count
    projects.joins("INNER JOIN http_endpoints ON http_endpoints.project_id = projects.id").count
  end

  def today_usage
    DailyUsageCounterRecord.today_for(id)
  end
end
