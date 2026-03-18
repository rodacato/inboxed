# frozen_string_literal: true

class DailyUsageCounterRecord < ApplicationRecord
  self.table_name = "daily_usage_counters"

  belongs_to :organization, class_name: "OrganizationRecord"

  def self.increment_emails!(organization_id)
    upsert_counter(organization_id, :emails_count)
  end

  def self.increment_requests!(organization_id)
    upsert_counter(organization_id, :requests_count)
  end

  def self.today_for(organization_id)
    find_or_initialize_by(organization_id: organization_id, date: Date.current)
  end

  private_class_method def self.upsert_counter(organization_id, column)
    today = Date.current
    result = where(organization_id: organization_id, date: today)
      .update_all("#{column} = #{column} + 1")

    if result == 0
      create!(:organization_id => organization_id, :date => today, column => 1)
    end
  rescue ActiveRecord::RecordNotUnique
    # Race condition: another thread created it, just increment
    where(organization_id: organization_id, date: today)
      .update_all("#{column} = #{column} + 1")
  end
end
