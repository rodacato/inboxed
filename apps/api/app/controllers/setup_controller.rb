# frozen_string_literal: true

class SetupController < ApplicationController
  before_action :ensure_setup_available

  def show
    render json: {setup_required: true}
  end

  def create
    unless valid_setup_token?
      error_message = if ENV["INBOXED_SETUP_TOKEN"].blank?
        "INBOXED_SETUP_TOKEN environment variable is not set"
      else
        "Invalid setup token"
      end
      return render json: {error: error_message}, status: :forbidden
    end

    result = Inboxed::Services::SetupInstance.new.call(
      email: params[:email],
      password: params[:password],
      org_name: params[:organization_name] || "Default"
    )

    session[:user_id] = result.user.id

    smtp_host = ENV.fetch("INBOXED_DOMAIN", "localhost")
    smtp_port = ENV.fetch("INBOXED_SMTP_PORT", "2525")

    render json: {
      data: serialize_user_with_org(result.user),
      setup: {
        project: {
          id: result.project.id,
          name: result.project.name,
          slug: result.project.slug
        },
        api_key: {
          id: result.api_key[:id],
          token: result.api_key[:token],
          token_prefix: result.api_key[:token_prefix],
          label: result.api_key[:label]
        },
        smtp: {
          host: smtp_host,
          port: smtp_port.to_i
        }
      }
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: {error: e.message}, status: :unprocessable_entity
  end

  private

  def ensure_setup_available
    if Inboxed::Settings.setup_completed?
      render json: {setup_required: false}, status: :ok
    end
  end

  def valid_setup_token?
    expected = ENV["INBOXED_SETUP_TOKEN"]
    return false unless expected.present?
    ActiveSupport::SecurityUtils.secure_compare(params[:setup_token].to_s, expected)
  end
end
