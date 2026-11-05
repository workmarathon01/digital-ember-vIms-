module Api
  module V1
    class BaseController < ApplicationController
      skip_before_action :verify_authenticity_token
      # Run before ApplicationController's authentication callback so JWT
      # authentication sees request.format.json? even if the client omits an
      # Accept header.
      prepend_before_action :force_json_format

      rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
      rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
      rescue_from ActiveRecord::RecordNotUnique, with: :render_conflict
      rescue_from Fcm::ConfigurationError, with: :render_push_unavailable
      rescue_from Fcm::AuthenticationError, with: :render_push_authentication_error
      rescue_from Fcm::TransientError, with: :render_push_unavailable

      private

      def force_json_format
        request.format = :json
      end

      def render_parameter_missing(error)
        render json: {
          error: {
            code: "missing_parameter",
            message: "Missing required parameter: #{error.param}"
          }
        }, status: :bad_request
      end

      def render_record_invalid(error)
        messages = error.record.errors.full_messages
        render json: {
          error: {
            code: "validation_failed",
            message: messages.to_sentence.presence || "Validation failed.",
            details: messages
          }
        }, status: :unprocessable_entity
      end

      def render_conflict
        render json: {
          error: {
            code: "conflict",
            message: "The device token was updated by another request. Retry the registration."
          }
        }, status: :conflict
      end

      def render_push_unavailable(error)
        Rails.logger.error("[Push] unavailable: #{error.class}: #{error.message}")
        render json: {
          error: {
            code: "push_unavailable",
            message: "Push notifications are temporarily unavailable."
          }
        }, status: :service_unavailable
      end

      def render_push_authentication_error(error)
        Rails.logger.error("[Push] authentication failed: #{error.message}")
        render json: {
          error: {
            code: "push_authentication_failed",
            message: "Push notifications are not configured correctly."
          }
        }, status: :bad_gateway
      end
    end
  end
end
