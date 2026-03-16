# frozen_string_literal: true

module TrialEnforced
  extend ActiveSupport::Concern

  included do
    before_action :require_active_org!, only: [:create, :update, :destroy]
  end
end
