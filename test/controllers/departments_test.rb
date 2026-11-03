require "test_helper"

class DepartmentsTest < ActionDispatch::IntegrationTest
  PASSWORD = "StrongPass!2026".freeze

  def setup
    @admin_role = Role.find_or_create_by!(key: "super_admin") do |role|
      role.name = "Super Administrator"
      role.power_level = 100
      role.is_system = true
    end

    @admin = User.create!(
      firstname: "Setup",
      lastname: "Admin",
      email: "setup-admin@example.test",
      password: PASSWORD,
      role: @admin_role
    )
  end

  def auth_headers(user = @admin)
    post session_path(format: :json), params: { email: user.email, password: PASSWORD }
    { "Authorization" => "Bearer #{response.parsed_body.fetch('access_token')}" }
  end

  test "departments can be listed created updated and deleted over JSON" do
    headers = auth_headers

    get departments_path(format: :json), headers: headers
    assert_response :success
    assert_equal [], response.parsed_body.fetch("data")

    post departments_path(format: :json),
         params: { department: { name: "Housekeeping", description: "Cleaning" } },
         headers: headers

    assert_response :created
    body = response.parsed_body
    assert_equal "Housekeeping", body.fetch("name")
    assert_equal "HOUSEKEEPING", body.fetch("code")
    department = Department.find(body.fetch("id"))

    patch department_path(department, format: :json),
          params: { department: { description: "Cleaning and upkeep" } },
          headers: headers

    assert_response :success
    assert_equal "Cleaning and upkeep", department.reload.description

    delete department_path(department, format: :json), headers: headers
    assert_response :no_content
    assert_not Department.exists?(department.id)
  end

  test "deleting a department unassigns its users" do
    department = Department.create!(name: "Security")
    user = User.create!(
      firstname: "Gate",
      lastname: "Guard",
      email: "gate-guard@example.test",
      password: PASSWORD,
      role: @admin_role,
      department: department
    )

    delete department_path(department, format: :json), headers: auth_headers

    assert_response :no_content
    assert_nil user.reload.department_id
  end

  test "a user without department permissions is forbidden" do
    viewer_role = Role.create!(name: "Viewer", key: "department_viewer", power_level: 5)
    viewer = User.create!(
      firstname: "Department",
      lastname: "Viewer",
      email: "department-viewer@example.test",
      password: PASSWORD,
      role: viewer_role
    )

    get departments_path(format: :json), headers: auth_headers(viewer)
    assert_response :forbidden
  end
end
