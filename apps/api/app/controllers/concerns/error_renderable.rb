# frozen_string_literal: true

# RFC 7807 Problem Details error responses (ADR-008, ADR-032)
module ErrorRenderable
  extend ActiveSupport::Concern

  PROBLEM_CONTENT_TYPE = "application/problem+json"
  ERROR_BASE_URL = "https://inboxed.notdefined.dev/docs/errors"

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :render_validation_error
    rescue_from ActionController::ParameterMissing, with: :render_bad_request
    rescue_from Inboxed::CurrentTenant::TenantNotSet, with: :render_unauthorized
    rescue_from Inboxed::PlanLimitExceeded, with: :render_plan_limit_exceeded
    rescue_from Inboxed::AddressBlocked, with: :render_address_blocked
  end

  private

  def render_not_found(exception)
    render_problem(
      type: "not-found",
      title: "Resource not found",
      detail: exception.message,
      status: :not_found
    )
  end

  def render_validation_error(exception)
    render_problem(
      type: "validation-error",
      title: "Validation failed",
      detail: "One or more request parameters are invalid.",
      status: :unprocessable_entity,
      extras: {
        errors: exception.record.errors.map { |e| {field: e.attribute.to_s, message: e.message} }
      }
    )
  end

  def render_bad_request(exception)
    render_problem(
      type: "bad-request",
      title: "Bad request",
      detail: exception.message,
      status: :bad_request
    )
  end

  def render_unauthorized(message = "Unauthorized")
    render_problem(
      type: "unauthorized",
      title: "Unauthorized",
      detail: message.to_s,
      status: :unauthorized
    )
  end

  def render_forbidden(message = "Forbidden")
    render_problem(
      type: "forbidden",
      title: "Forbidden",
      detail: message.to_s,
      status: :forbidden
    )
  end

  def render_plan_limit_exceeded(exception)
    render_problem(
      type: "plan-limit-reached",
      title: "Plan limit reached",
      detail: exception.message,
      status: :forbidden,
      extras: {
        limit: exception.limit,
        current: exception.current,
        max: exception.max
      }.compact
    )
  end

  def render_address_blocked(exception)
    render_problem(
      type: "address-blocked",
      title: "Address blocked",
      detail: exception.message,
      status: :forbidden
    )
  end

  def render_problem(type:, title:, detail:, status:, extras: {})
    status_code = Rack::Utils.status_code(status)
    body = {
      type: "#{ERROR_BASE_URL}/#{type}",
      title: title,
      detail: detail,
      status: status_code
    }.merge(extras)

    render json: body, status: status, content_type: PROBLEM_CONTENT_TYPE
  end
end
