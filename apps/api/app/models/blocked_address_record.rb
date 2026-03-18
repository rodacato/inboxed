# frozen_string_literal: true

class BlockedAddressRecord < ApplicationRecord
  self.table_name = "blocked_addresses"

  validates :address, presence: true, uniqueness: {case_sensitive: false}

  before_validation :normalize_address

  scope :matching, ->(address) {
    where("address = ? OR ? LIKE REPLACE(address, '*', '%')", address.downcase, address.downcase)
  }

  def self.blocked?(address)
    return false if address.blank?
    matching(address.downcase.strip).exists?
  end

  private

  def normalize_address
    self.address = address&.strip&.downcase
  end
end
