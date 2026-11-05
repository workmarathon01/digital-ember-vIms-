module Fcm
  # Immutable outcome of one FCM send. The raw token is kept so the caller can
  # remove or disable the matching device row, but it is never logged.
  class Result
    attr_reader :token, :message_id, :error_code, :error_status, :error_message, :http_status

    def initialize(token:, success:, message_id: nil, error_code: nil, error_status: nil,
                   error_message: nil, http_status: nil)
      @token = token
      @success = success
      @message_id = message_id
      @error_code = error_code
      @error_status = error_status
      @error_message = error_message
      @http_status = http_status
    end

    def success?
      @success
    end

    def failure?
      !@success
    end

    # FCM permanently rejects a token with these codes. The device row should be
    # disabled so future sends do not keep retrying a dead installation.
    def invalid_token?
      return false if success?

      return true if error_code == "UNREGISTERED" || error_code == "SENDER_ID_MISMATCH"

      error_code == "INVALID_ARGUMENT" &&
        error_message.to_s.match?(/registration token|not a valid.*token/i)
    end

    def retryable?
      [ 429, 500, 502, 503, 504 ].include?(http_status) ||
        %w[UNAVAILABLE INTERNAL].include?(error_code)
    end

    def to_h
      {
        success: success?,
        message_id: message_id,
        error_code: error_code,
        error_status: error_status,
        error_message: error_message,
        http_status: http_status
      }
    end
  end
end
