module Api
  module V1
    class PushTokensController < BaseController
      before_action :set_push_token, only: %i[show update destroy test_notification]

      def index
        render json: { data: current_user.push_tokens.recent.map(&:as_api_json) }
      end

      def show
        render json: { data: @push_token.as_api_json }
      end

      # Idempotent registration. The mobile app calls this on launch, after
      # login, and whenever FCM rotates the token.
      def create
        push_token = PushToken.register!(
          user: current_user,
          uuid: params.require(:uuid),
          token: params.require(:token),
          platform: params[:platform],
          device_name: params[:device_name],
          app_version: params[:app_version],
          os_version: params[:os_version],
          locale: params[:locale],
          timezone: params[:timezone]
        )

        render json: { data: push_token.as_api_json },
               status: push_token.previously_new_record? ? :created : :ok
      end

      def update
        @push_token.update!(update_params)
        render json: { data: @push_token.as_api_json }
      end

      def destroy
        @push_token.destroy!
        head :no_content
      end

      # Called during logout on the current device when the client does not know
      # the uuid, or for "log out everywhere".
      def unregister_all
        current_user.push_tokens.delete_all
        head :no_content
      end

      # Synchronous diagnostic endpoint. It uses the real FCM path so the app
      # developer can verify the token, credentials and platform setup together.
      def test_notification
        unless @push_token.enabled?
          return render json: {
            error: {
              code: "push_token_disabled",
              message: "Enable the device before sending a test notification."
            }
          }, status: :unprocessable_entity
        end

        results = PushNotifier.deliver_to_token(
          @push_token,
          title: params[:title].presence || "Test notification",
          body: params[:body].presence || "Push notifications are working.",
          data: { "type" => "test" },
          async: false
        )

        render json: {
          data: {
            sent: results.count(&:success?),
            failed: results.count(&:failure?),
            tokens: results.size
          }
        }
      end

      private

      def set_push_token
        @push_token = current_user.push_tokens.find_by!(uuid: params[:uuid])
      end

      # Token rotation goes through `create` (upsert), never through PATCH. That
      # keeps the unique token/uuid invariants in one place.
      def update_params
        params.permit(:enabled, :platform, :device_name, :app_version, :os_version, :locale, :timezone)
      end
    end
  end
end
