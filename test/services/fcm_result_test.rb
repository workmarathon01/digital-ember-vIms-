require "test_helper"

class FcmResultTest < ActiveSupport::TestCase
  test "UNREGISTERED marks the token as invalid" do
    result = Fcm::Result.new(token: "t", success: false, error_code: "UNREGISTERED")

    assert result.invalid_token?
  end

  test "SENDER_ID_MISMATCH marks the token as invalid" do
    result = Fcm::Result.new(token: "t", success: false, error_code: "SENDER_ID_MISMATCH")

    assert result.invalid_token?
  end

  test "INVALID_ARGUMENT only invalidates a token when the message is about the token" do
    token_error = Fcm::Result.new(
      token: "t", success: false, error_code: "INVALID_ARGUMENT",
      error_message: "The registration token is not a valid FCM registration token"
    )
    payload_error = Fcm::Result.new(
      token: "t", success: false, error_code: "INVALID_ARGUMENT",
      error_message: "Invalid notification payload"
    )

    assert token_error.invalid_token?
    assert_not payload_error.invalid_token?
  end

  test "transient HTTP statuses are retryable" do
    assert Fcm::Result.new(token: "t", success: false, http_status: 503).retryable?
    assert_not Fcm::Result.new(token: "t", success: false, http_status: 400).retryable?
  end
end
