module Api
  module V1
    class StatusController < BaseController
      def show
        render json: {
          service: "inboxed-api",
          version: "0.0.1",
          status: "ok",
          timestamp: Time.current.iso8601
        }
      end
    end
  end
end
