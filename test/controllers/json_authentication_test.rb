require "test_helper"

class JsonAuthenticationTest < ActionDispatch::IntegrationTest
  PASSWORD = "StrongPass!2026".freeze

  def setup
    role = Role.find_or_create_by!(key: "admin") do |r|
      r.name = "Admin User"
      r.power_level = 100
      r.is_system = true
    end
    @user = User.create!(
      firstname: "Api", lastname: "Tester", email: "api-admin@example.test",
      password: PASSWORD, role: role
    )
  end

  def sign_in
    post session_path(format: :json), params: { email: @user.email, password: PASSWORD }
    response.parsed_body
  end

  test "json login returns access and refresh tokens" do
    body = sign_in

    assert_response :success
    assert_equal "Bearer", body["token_type"]
    assert body["access_token"].present?
    assert body["refresh_token"].present?
    assert_equal JsonWebToken.access_ttl, body["expires_in"]
    assert_equal @user.id, body.dig("user", "id")
    assert_not body.key?("password_digest")
  end

  test "json login with wrong password is unauthorized" do
    post session_path(format: :json), params: { email: @user.email, password: "wrong-password" }

    assert_response :unauthorized
    assert_equal "invalid_credentials", response.parsed_body.dig("error", "code")
  end

  test "json request without a token is unauthorized" do
    get visitors_path(format: :json)

    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body.dig("error", "code")
    assert_match(/Bearer/, response.headers["WWW-Authenticate"])
  end

  test "json request with an invalid token is unauthorized" do
    get visitors_path(format: :json), headers: { "Authorization" => "Bearer not-a-real-token" }

    assert_response :unauthorized
    assert_equal "invalid_token", response.parsed_body.dig("error", "code")
  end

  test "json request with an expired access token is unauthorized" do
    expired = JsonWebToken.encode(@user, JsonWebToken::ACCESS_TYPE, -60)

    get visitors_path(format: :json), headers: { "Authorization" => "Bearer #{expired}" }

    assert_response :unauthorized
    assert_equal "token_expired", response.parsed_body.dig("error", "code")
  end

  test "json request with a valid access token is authorized" do
    access = sign_in.fetch("access_token")

    get visitors_path(format: :json), headers: { "Authorization" => "Bearer #{access}" }

    assert_response :success
  end

  test "refresh token issues a new token pair" do
    refresh = sign_in.fetch("refresh_token")

    post refresh_session_path(format: :json), params: { refresh_token: refresh }

    assert_response :success
    body = response.parsed_body
    assert body["access_token"].present?
    assert body["refresh_token"].present?
    assert_not_equal refresh, body["refresh_token"]
  end

  test "an access token cannot be used to refresh" do
    access = sign_in.fetch("access_token")

    post refresh_session_path(format: :json), params: { refresh_token: access }

    assert_response :unauthorized
    assert_equal "invalid_token", response.parsed_body.dig("error", "code")
  end

  test "json login is not blocked by csrf origin checks" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    begin
      post session_path(format: :json),
           params: { email: @user.email, password: PASSWORD },
           headers: { "Origin" => "https://horizonemployeeportal.vibecopilot.ai" }

      assert_response :success
      assert response.parsed_body["access_token"].present?
    ensure
      ActionController::Base.allow_forgery_protection = original
    end
  end

  test "html session flow still works" do
    post session_path, params: { email: @user.email, password: PASSWORD }
    assert_redirected_to root_path

    get visitors_path
    assert_response :success
  end
end
