# frozen_string_literal: true

module Paginatable
  extend ActiveSupport::Concern

  private

  def pagination_limit
    [params.fetch(:limit, 20).to_i, 100].min
  end

  def pagination_meta(result)
    last_record = result[:records].last
    {
      has_more: result[:has_more],
      next_cursor: result[:has_more] ? encode_cursor(last_record) : nil,
      total_count: result[:total_count]
    }
  end

  def encode_cursor(record)
    return nil unless record
    sort_key = record.try(:received_at) || record.created_at
    Base64.urlsafe_encode64({t: sort_key.iso8601(6), id: record.id}.to_json)
  end

  def decode_cursor(cursor)
    return nil unless cursor
    JSON.parse(Base64.urlsafe_decode64(cursor)).symbolize_keys
  end
end
