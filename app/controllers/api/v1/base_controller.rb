module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate_ingest_token!

      private

      def authenticate_ingest_token!
        expected_token = ENV["INGEST_BEARER_TOKEN"].to_s

        if expected_token.blank?
          render json: { error: "Server INGEST_BEARER_TOKEN is not configured" }, status: :internal_server_error
          return
        end

        authenticated = authenticate_with_http_token do |token, _options|
          ActiveSupport::SecurityUtils.secure_compare(token.to_s, expected_token)
        end

        return if authenticated

        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end
  end
end
