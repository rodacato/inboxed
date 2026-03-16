# frozen_string_literal: true

module ErrorRenderable
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :render_validation_error
    rescue_from ActionController::ParameterMissing, with: :render_bad_request
    rescue_from Inboxed::CurrentTenant::TenantNotSet, with: :render_unauthorized
  end

  private

  def render_not_found(exception)
    render json: {
      error: "Not found",
      detail: exception.message
    }, status: :not_found
  end

  def render_validation_error(exception)
    render json: {
      error: "Validation failed",
      detail: exception.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  def render_bad_request(exception)
    render json: {
      error: "Bad request",
      detail: exception.message
    }, status: :bad_request
  end

  def render_unauthorized(message = "Unauthorized")
    render json: {error: message.to_s}, status: :unauthorized
  end
end
