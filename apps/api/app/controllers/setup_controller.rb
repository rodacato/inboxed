# frozen_string_literal: true

class SetupController < ApplicationController
  before_action :ensure_setup_available

  def show
    render json: {setup_required: true}
  end

  def create
    return head :forbidden unless valid_setup_token?

    result = Inboxed::Services::SetupInstance.new.call(
      email: params[:email],
      password: params[:password],
      org_name: params[:org_name] || "Default"
    )

    session[:user_id] = result.user.id
    render json: {data: serialize_user_with_org(result.user)}, status: :created
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
