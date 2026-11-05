require "test_helper"

class Api::V1::PushTokensTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  PASSWORD = "StrongPass!2026".freeze

  def setup
    role = Role.find_or_create_by!(key: "super_admin") do |record|
      record.name = "Super Administrator"
      record.power_level = 100
      record.is_system = true
    end

    @user = User.create!(
      firstname: "Api", lastname: "Push", email: "api-push-#{SecureRandom.hex(4)}@example.test",
      password: PASSWORD, role: role
    )
    @access = JsonWebToken.encode_access(@user)
  end

  def headers
    { "Authorization" => "Bearer #{@access}" }
  end

  def create_device(uuid: "device-1", token: "fcm-token-1", user: @user)
    PushToken.register!(user: user, uuid: uuid, token: token)
  end

  test "requires authentication" do
    get api_v1_push_tokens_path

    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body.dig("error", "code")
  end

  test "registers a device" do
    post api_v1_push_tokens_path,
         params: {
           uuid: "device-1",
           token: "fcm-token-1",
           platform: "android",
           device_name: "Pixel 8",
           app_version: "1.0.0"
         },
         headers: headers,
         as: :json

    assert_response :created
    body = response.parsed_body
    assert_equal "device-1", body.dig("data", "uuid")
    assert_equal "android", body.dig("data", "platform")
    assert_not body.dig("data").key?("token")
    assert_equal 1, @user.push_tokens.count
  end

  test "re-registering the same device is an upsert and rotates the token" do
    create_device

    post api_v1_push_tokens_path,
         params: { uuid: "device-1", token: "fcm-token-2", app_version: "1.1.0" },
         headers: headers,
         as: :json

    assert_response :ok
    assert_equal "fcm-token-2", @user.push_tokens.find_by(uuid: "device-1").token
    assert_equal 1, @user.push_tokens.count
  end

  test "lists only the current user's devices" do
    create_device(uuid: "mine", token: "mine-token")

    other = User.create!(
      firstname: "Other", lastname: "Push", email: "other-push-#{SecureRandom.hex(4)}@example.test",
      password: PASSWORD
    )
    create_device(user: other, uuid: "theirs", token: "theirs-token")

    get api_v1_push_tokens_path, headers: headers, as: :json

    assert_response :success
    uuids = response.parsed_body["data"].map { |record| record["uuid"] }
    assert_equal [ "mine" ], uuids
  end

  test "updates device metadata and enablement" do
    create_device

    patch api_v1_push_token_path("device-1"),
          params: { enabled: false, device_name: "Old phone" },
          headers: headers,
          as: :json

    assert_response :success
    token = @user.push_tokens.find_by(uuid: "device-1")
    assert_not token.enabled?
    assert_equal "Old phone", token.device_name
  end

  test "cannot read or modify another user's device" do
    other = User.create!(
      firstname: "Other", lastname: "Push", email: "other-push-#{SecureRandom.hex(4)}@example.test",
      password: PASSWORD
    )
    create_device(user: other, uuid: "theirs", token: "theirs-token")

    get api_v1_push_token_path("theirs"), headers: headers, as: :json
    assert_response :not_found

    patch api_v1_push_token_path("theirs"), params: { enabled: false }, headers: headers, as: :json
    assert_response :not_found

    delete api_v1_push_token_path("theirs"), headers: headers, as: :json
    assert_response :not_found

    assert PushToken.exists?(uuid: "theirs")
  end

  test "removes one device on logout" do
    create_device

    delete api_v1_push_token_path("device-1"), headers: headers, as: :json

    assert_response :no_content
    assert_not PushToken.exists?(uuid: "device-1")
  end

  test "unregisters every device for the current user" do
    create_device(uuid: "one", token: "one-token")
    create_device(uuid: "two", token: "two-token")

    other = User.create!(
      firstname: "Other", lastname: "Push", email: "other-push-#{SecureRandom.hex(4)}@example.test",
      password: PASSWORD
    )
    create_device(user: other, uuid: "theirs", token: "theirs-token")

    delete unregister_all_api_v1_push_tokens_path, headers: headers, as: :json

    assert_response :no_content
    assert_equal 0, @user.push_tokens.count
    assert PushToken.exists?(uuid: "theirs")
  end

  test "sends a diagnostic test notification" do
    create_device

    fake = lambda do |_push_token, **|
      [ Fcm::Result.new(token: "fcm-token-1", success: true, message_id: "projects/x/messages/1") ]
    end

    with_stubbed_method(PushNotifier, :deliver_to_token, fake) do
      post test_notification_api_v1_push_token_path("device-1"), headers: headers, as: :json
    end

    assert_response :success
    assert_equal 1, response.parsed_body.dig("data", "sent")
  end

  test "does not send a test to a disabled device" do
    create_device.update!(enabled: false)

    assert_no_enqueued_jobs do
      post test_notification_api_v1_push_token_path("device-1"), headers: headers, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal "push_token_disabled", response.parsed_body.dig("error", "code")
  end

  test "returns a clear error when required parameters are missing" do
    post api_v1_push_tokens_path, params: { uuid: "device-1" }, headers: headers, as: :json

    assert_response :bad_request
    assert_equal "missing_parameter", response.parsed_body.dig("error", "code")
  end
end
