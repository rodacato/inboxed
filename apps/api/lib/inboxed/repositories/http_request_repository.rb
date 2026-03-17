# frozen_string_literal: true

module Inboxed
  module Repositories
    class HttpRequestRepository
      def save(endpoint_id:, request_data:, expires_at: nil)
        record = HttpRequestRecord.create!(
          http_endpoint_id: endpoint_id,
          method: request_data[:method],
          path: request_data[:path],
          query_string: request_data[:query_string],
          headers: request_data[:headers] || {},
          body: request_data[:body],
          content_type: request_data[:content_type],
          ip_address: request_data[:ip_address],
          size_bytes: request_data[:size_bytes] || 0,
          received_at: Time.current,
          expires_at: expires_at
        )
        to_entity(record)
      end

      def find(id, endpoint_id:)
        record = HttpRequestRecord.where(http_endpoint_id: endpoint_id).find(id)
        to_entity(record)
      end

      def find_latest(endpoint_id:, method: nil)
        scope = HttpRequestRecord
          .where(http_endpoint_id: endpoint_id)
          .order(received_at: :desc)
        scope = scope.where(method: method.upcase) if method.present?
        record = scope.first
        record ? to_entity(record) : nil
      end

      def list_for_endpoint(endpoint_id:, method: nil, limit: 20)
        scope = HttpRequestRecord
          .where(http_endpoint_id: endpoint_id)
          .order(received_at: :desc)
          .limit(limit)
        scope = scope.where(method: method.upcase) if method.present?
        scope.map { |r| to_entity(r) }
      end

      def destroy(id, endpoint_id:)
        record = HttpRequestRecord.where(http_endpoint_id: endpoint_id).find(id)
        record.destroy!
      end

      def delete_all_for_endpoint(endpoint_id:)
        HttpRequestRecord.where(http_endpoint_id: endpoint_id).delete_all
      end

      private

      def to_entity(record)
        Entities::HttpRequest.new(
          id: record.id,
          http_endpoint_id: record.http_endpoint_id,
          method: record.method,
          path: record.path,
          query_string: record.query_string,
          headers: record.headers || {},
          body: record.body,
          content_type: record.content_type,
          ip_address: record.ip_address,
          size_bytes: record.size_bytes || 0,
          received_at: record.received_at,
          expires_at: record.expires_at
        )
      end
    end
  end
end
