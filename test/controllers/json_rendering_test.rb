require "test_helper"

class JsonRenderingTest < ActionDispatch::IntegrationTest
  def setup
    role = Role.find_or_create_by!(key: "super_admin") do |r|
      r.name = "Super Administrator"
      r.power_level = 100
      r.is_system = true
    end
    @admin = User.create!(
      firstname: "Admin", lastname: "Tester", email: "json-admin@example.test",
      password: "StrongPass!2026", role: role
    )
    @visitor = Visitor.create!(name: "Jane Visitor", contact_no: "9876543210", created_by: @admin)
    @visitor.profile_image.attach(
      io: StringIO.new(File.binread(Rails.root.join("test/fixtures/files/profile.png"))),
      filename: "profile.png",
      content_type: "image/png"
    )
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
    assert response.parsed_body.dig("visitors", 0, "qr_token").present?

    get visitor_path(@visitor, format: :json), headers: auth_headers
    assert_json_ok
    assert_equal @visitor.id, response.parsed_body["id"]
    assert response.parsed_body["qr_token"].present?
    assert response.parsed_body["profile_image_url"].present?
  end

  test "staff can create a visitor with a profile photo using a multipart request" do
    assert_difference("Visitor.count", 1) do
      post visitors_path(format: :json), headers: auth_headers, params: {
        visitor: {
          name: "Photo Visitor",
          contact_no: "9876500099",
          profile_image: fixture_file_upload("profile.png", "image/png")
        }
      }
    end

    assert_response :created
    assert response.parsed_body.dig("profile_image_url").present?
    assert Visitor.order(:created_at).last.profile_image.attached?
  end

  test "new visitor form includes profile photo and host fields" do
    post session_path, params: { email: @admin.email, password: "StrongPass!2026" }

    get new_visitor_path

    assert_response :success
    assert_select "input[type='file'][name='visitor[profile_image]']"
    assert_select "select[name='visitor[vhost_id]']"
  end

  test "visitor pages render the uploaded profile photo" do
    post session_path, params: { email: @admin.email, password: "StrongPass!2026" }

    get visitor_path(@visitor)

    assert_response :success
    assert_select "img.profile-photo"

    get visitors_path

    assert_response :success
    assert_select "img.avatar"
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

  test "users index paginates ten records per page" do
    get users_path(format: :json), headers: auth_headers

    assert_json_ok
    assert_equal 10, response.parsed_body.dig("meta", "limit")
  end

  test "staff can create a user with a profile photo using a multipart request" do
    assert_difference("User.count", 1) do
      post users_path(format: :json), headers: auth_headers, params: {
        user: {
          firstname: "Photo",
          lastname: "User",
          email: "photo-user@example.test",
          password: "StrongPass!2026",
          profile_image: fixture_file_upload("profile.png", "image/png")
        }
      }
    end

    assert_response :created
    assert response.parsed_body["profile_image_url"].present?
    assert User.find_by(email: "photo-user@example.test").profile_image.attached?
  end

  test "staff can update a user with a profile photo using a multipart request" do
    user = User.create!(
      firstname: "Edit", lastname: "Target", email: "edit-target@example.test",
      password: "StrongPass!2026"
    )

    patch user_path(user, format: :json), headers: auth_headers, params: {
      user: {
        firstname: "Updated",
        profile_image: fixture_file_upload("profile.png", "image/png")
      }
    }

    assert_response :success
    assert_equal "Updated", user.reload.firstname
    assert user.profile_image.attached?
    assert response.parsed_body["profile_image_url"].present?
  end

  test "staff can toggle a user active status with a json request" do
    user = User.create!(
      firstname: "Toggle", lastname: "Target", email: "toggle-target@example.test",
      password: "StrongPass!2026"
    )

    patch user_path(user, format: :json), headers: auth_headers, params: {
      user: { active: false }
    }

    assert_response :success
    assert_not user.reload.active
    assert_equal false, response.parsed_body["active"]
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
