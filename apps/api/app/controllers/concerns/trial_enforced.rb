# frozen_string_literal: true

module TrialEnforced
  extend ActiveSupport::Concern

  WRITE_ACTIONS = %w[create update destroy].freeze

  included do
    before_action :enforce_active_trial
  end

  private

  def enforce_active_trial
    return unless WRITE_ACTIONS.include?(action_name)

    require_active_org!
  end
end
