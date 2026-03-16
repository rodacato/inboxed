# frozen_string_literal: true

class ApplicationController < ActionController::API
  include ActionController::Cookies

  private

  def current_user
    @current_user ||= UserRecord.find_by(id: session[:user_id])
  end

  def require_auth!
    head :unauthorized unless current_user
  end

  def require_active_org!
    org = current_user&.organization
    return head :unauthorized unless org

    unless org.active?
      render json: {
        error: "trial_expired",
        message: "Your trial has expired. Contact the administrator for permanent access.",
        trial_ended_at: org.trial_ends_at&.iso8601
      }, status: :forbidden
    end
  end

  def with_tenant(&block)
    return yield unless current_user

    org = current_user.organization
    return head :unauthorized unless org

    Inboxed::CurrentTenant.set(user: current_user, organization: org, &block)
  end

  def serialize_user_with_org(user)
    org = user.organization
    data = {
      id: user.id,
      email: user.email,
      role: user.role_in(org),
      site_admin: user.site_admin?,
      verified: user.verified?,
      last_sign_in_at: user.last_sign_in_at&.iso8601,
      sign_in_count: user.sign_in_count
    }

    if org
      data[:organization] = {
        id: org.id,
        name: org.name,
        slug: org.slug,
        trial: org.trial?,
        trial_ends_at: org.trial_ends_at&.iso8601,
        trial_active: org.trial? ? org.trial_active? : nil,
        days_remaining: org.days_remaining
      }
    end

    data
  end

  def requires_verification?
    ENV["OUTBOUND_SMTP_HOST"].present?
  end

  def outbound_smtp_configured?
    ENV["OUTBOUND_SMTP_HOST"].present?
  end
end
