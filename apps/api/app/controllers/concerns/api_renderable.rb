# frozen_string_literal: true

module ApiRenderable
  extend ActiveSupport::Concern

  private

  # Render a paginated collection with resource-named envelope (ADR-008, ADR-032)
  #
  #   render_collection(:emails, result[:records], result, serializer: EmailListSerializer)
  #   → { "emails": [...], "pagination": { "has_more": true, "next_cursor": "...", "total_count": 128 } }
  def render_collection(resource_name, records, result, serializer: nil, status: :ok)
    serialized = if serializer
      records.map { |r| serializer.render(r) }
    else
      records
    end

    render json: {
      resource_name => serialized,
      pagination: pagination_meta(result)
    }, status: status
  end

  # Render a single resource with resource-named envelope (ADR-008, ADR-032)
  #
  #   render_resource(:endpoint, record, serializer: HttpEndpointSerializer)
  #   → { "endpoint": { ... } }
  def render_resource(resource_name, record, serializer: nil, status: :ok)
    serialized = serializer ? serializer.render(record) : record
    render json: {resource_name => serialized}, status: status
  end
end
