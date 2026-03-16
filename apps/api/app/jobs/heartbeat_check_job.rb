# frozen_string_literal: true

class HeartbeatCheckJob < ApplicationJob
  queue_as :default

  def perform
    Inboxed::Services::CheckHeartbeats.new.call
  end
end
