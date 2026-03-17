# frozen_string_literal: true

class ReceiveEmailJob < ApplicationJob
  queue_as :default

  def perform(project_id:, envelope_from:, envelope_to:, raw_source:, source_type:, api_key_id: nil)
    Inboxed::Services::ReceiveEmail.new.call(
      project_id: project_id,
      raw_source: raw_source,
      envelope_to: Array(envelope_to),
      source_type: source_type
    )

    ApiKeyRecord.where(id: api_key_id).update_all(last_used_at: Time.current) if api_key_id
  end
end
