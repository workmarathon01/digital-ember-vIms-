require "test_helper"

class JsonRenderingTest < ActionDispatch::IntegrationTest
  def setup
    role = Role.find_or_create_by!(key: "admin") do |r|
      r.name = "Admin User"
      r.power_level = 100
      r.is_system = true
    end
    @admin = User.create!(
      firstname: "Admin", lastname: "Tester", email: "json-admin@example.test",
      password: "StrongPass!2026", role: role
    )
    @visitor = Visitor.create!(name: "Jane Visitor", contact_no: "9876543210", created_by: @admin)
    @staff = Staff.create!(firstname: "John", lastname: "Staff", mobile_no: "9876500000", created_by: @admin)
    sign_in
  end

  def sign_in
    post session_path(format: :json), params: { email: @admin.email, password: "StrongPass!2026" }
    @access_token = response.parsed_body.fetch("access_token")
    @refresh_token = response.parsed_body.fetch("refresh_token")
  end

  def auth_headers
    { "Authorization" => "Bearer #{@access_token}" }
  end

  def assert_json_ok
    assert_response :success
    assert_equal "application/json", response.media_type
  end

  test "visitors index and show render json" do
    get visitors_path(format: :json), headers: auth_headers
    assert_json_ok
    assert response.parsed_body.key?("meta")

    get visitor_path(@visitor, format: :json), headers: auth_headers
    assert_json_ok
    assert_equal @visitor.id, response.parsed_body["id"]
  end

  test "staffs index and show render json" do
    get staffs_path(format: :json), headers: auth_headers
    assert_json_ok

    get staff_path(@staff, format: :json), headers: auth_headers
    assert_json_ok
    assert_equal @staff.full_name, response.parsed_body["full_name"]
  end

  test "users index and show render json" do
    get users_path(format: :json), headers: auth_headers
    assert_json_ok

    get user_path(@admin, format: :json), headers: auth_headers
    assert_json_ok
    assert response.parsed_body.key?("audit_logs")
  end

  test "roles index and show render json" do
    get roles_path(format: :json), headers: auth_headers
    assert_json_ok

    get role_path(@admin.role, format: :json), headers: auth_headers
    assert_json_ok
    assert response.parsed_body.key?("members")
  end

  test "audit logs index renders json" do
    get audit_logs_path(format: :json), headers: auth_headers
    assert_json_ok
    assert response.parsed_body["data"].is_a?(Array)
  end

  test "dashboard renders json" do
    get root_path(format: :json), headers: auth_headers
    assert_json_ok
    assert response.parsed_body.key?("users_count")
  end
end
