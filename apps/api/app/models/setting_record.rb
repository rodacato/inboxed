# frozen_string_literal: true

class SettingRecord < ApplicationRecord
  self.table_name = "settings"

  validates :key, presence: true, uniqueness: true
end
