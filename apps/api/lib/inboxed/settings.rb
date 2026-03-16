# frozen_string_literal: true

module Inboxed
  class Settings
    def self.setup_completed?
      get(:setup_completed_at).present? || UserRecord.where(site_admin: true).exists?
    end

    def self.get(key)
      SettingRecord.find_by(key: key.to_s)&.value
    end

    def self.set(key, value)
      record = SettingRecord.find_or_initialize_by(key: key.to_s)
      record.update!(value: value.to_s)
    end
  end
end
