# frozen_string_literal: true

module Admin
  class ApiKeysController < BaseController
    def index
      project = ProjectRecord.find(params[:project_id])
      api_keys = ApiKeyRecord.where(project_id: project.id).order(created_at: :desc)

      render json: {
        api_keys: api_keys.map { |k| serialize_api_key(k) }
      }
    end

    def create
      project = ProjectRecord.find(params[:project_id])
      key_params = params.fetch(:api_key, {}).permit(:label)

      result = Inboxed::Services::IssueApiKey.new.call(
        project_id: project.id,
        label: key_params[:label]
      )

      render json: {
        api_key: {
          id: result[:id],
          label: result[:label],
          token: result[:token],
          token_prefix: result[:token_prefix],
          created_at: ApiKeyRecord.find(result[:id]).created_at.iso8601
        }
      }, status: :created
    end

    def update
      api_key = ApiKeyRecord.find(params[:id])
      key_params = params.require(:api_key).permit(:label)
      api_key.update!(key_params)

      render json: {api_key: serialize_api_key(api_key)}
    end

    def destroy
      api_key = ApiKeyRecord.find(params[:id])
      api_key.destroy!
      head :no_content
    end

    private

    def serialize_api_key(record)
      {
        id: record.id,
        label: record.label,
        token_prefix: record.token_prefix,
        last_used_at: record.last_used_at&.iso8601,
        created_at: record.created_at.iso8601
      }
    end
  end
end
