# frozen_string_literal: true

require "rails_helper"

RSpec.describe SettingRecord, type: :model do
  describe "validations" do
    it "validates key uniqueness" do
      SettingRecord.create!(key: "unique_key", value: "first")
      duplicate = SettingRecord.new(key: "unique_key", value: "second")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:key]).to include("has already been taken")
    end

    it "validates key presence" do
      setting = SettingRecord.new(key: nil, value: "test")
      expect(setting).not_to be_valid
      expect(setting.errors[:key]).to include("can't be blank")
    end
  end
end
