module Api
  module V1
    class BaseController < ApplicationController
      before_action :authenticate_api_key!

      private

      def authenticate_api_key!
        token = extract_bearer_token
        if token.blank?
          render json: {error: "API key required", code: "unauthorized"}, status: :unauthorized
        end
        # TODO: validate against DB in data models spec
      end

      def extract_bearer_token
        request.headers["Authorization"]&.match(/\ABearer\s+(.+)\z/)&.captures&.first
      end
    end
  end
end
