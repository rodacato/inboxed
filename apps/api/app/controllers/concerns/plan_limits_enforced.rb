# frozen_string_literal: true

# Enforces organization plan limits on resource creation.
# Permanent orgs have no limits. Trial orgs are capped.
module PlanLimitsEnforced
  extend ActiveSupport::Concern

  private

  def enforce_inbox_limit!
    org = current_user&.organization
    return unless org&.max_inboxes

    if org.total_inbox_count >= org.max_inboxes
      render json: {
        error: "plan_limit_reached",
        message: "You've reached the maximum of #{org.max_inboxes} inboxes for your plan.",
        limit: "max_inboxes",
        current: org.total_inbox_count,
        max: org.max_inboxes
      }, status: :forbidden
    end
  end

  def enforce_endpoint_limit!
    org = current_user&.organization
    return unless org&.max_endpoints

    if org.total_endpoint_count >= org.max_endpoints
      render json: {
        error: "plan_limit_reached",
        message: "You've reached the maximum of #{org.max_endpoints} endpoints for your plan.",
        limit: "max_endpoints",
        current: org.total_endpoint_count,
        max: org.max_endpoints
      }, status: :forbidden
    end
  end

  def enforce_daily_email_limit!(organization_id)
    org = OrganizationRecord.find(organization_id)
    return unless org.max_emails_per_day

    usage = org.today_usage
    if usage.emails_count >= org.max_emails_per_day
      raise Inboxed::PlanLimitExceeded.new(
        "Daily email limit of #{org.max_emails_per_day} reached",
        limit: "max_emails_per_day",
        current: usage.emails_count,
        max: org.max_emails_per_day
      )
    end
  end

  def enforce_daily_request_limit!(organization_id)
    org = OrganizationRecord.find(organization_id)
    return unless org.max_requests_per_day

    usage = org.today_usage
    if usage.requests_count >= org.max_requests_per_day
      raise Inboxed::PlanLimitExceeded.new(
        "Daily request limit of #{org.max_requests_per_day} reached",
        limit: "max_requests_per_day",
        current: usage.requests_count,
        max: org.max_requests_per_day
      )
    end
  end
end
