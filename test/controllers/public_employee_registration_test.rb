require "test_helper"

class PublicEmployeeRegistrationTest < ActionDispatch::IntegrationTest
  def setup
    @site = Site.create!(name: "Employee Campus", code: "EMP#{SecureRandom.hex(3).upcase}")
    @department = Department.create!(name: "Employee Operations #{SecureRandom.hex(2)}")
    Role.find_or_create_by!(key: "staff") do |role|
      role.name = "Operations Staff"
      role.power_level = 30
      role.is_system = true
    end
    @super_admin = create_role_and_user(:super_admin, "Super Admin", "employee-super-#{SecureRandom.hex(3)}@example.test", 100)
    @admin = create_role_and_user(:admin, "Admin User", "employee-admin-#{SecureRandom.hex(3)}@example.test", 90)
    @security = create_role_and_user(:security, "Security User", "employee-security-#{SecureRandom.hex(3)}@example.test", 60)
  end

  def create_role_and_user(key, name, email, level)
    role = Role.find_or_create_by!(key: key) do |record|
      record.name = name
      record.power_level = level
      record.is_system = true
    end

    grant_admin_permissions(role) if key == :admin
    role.permissions.find_or_create_by!(resource: "visitors", action: "read") if key == :security

    User.create!(
      firstname: name.split.first,
      lastname: "Tester",
      email: email,
      password: "StrongPass!2026",
      role: role
    )
  end

  def grant_admin_permissions(role)
    Role::RESOURCES.each do |resource|
      actions = resource[:key] == "roles" ? %w[read] : resource[:actions]
      actions.each do |action|
        role.permissions.find_or_create_by!(resource: resource[:key], action: action)
      end
    end
  end

  def registration_params(overrides = {})
    {
      employee_registration: {
        firstname: "Asha",
        lastname: "Employee",
        email: "asha.employee.#{SecureRandom.hex(3)}@example.test",
        mobile: "98765 00011",
        password: "StrongPass!2026",
        password_confirmation: "StrongPass!2026",
        current_site_id: @site.id,
        department_id: @department.id,
        position: "Facility Executive",
        date_of_joining: Date.current.iso8601
      }.merge(overrides)
    }
  end

  def sign_in(email)
    post session_path, params: { email: email, password: "StrongPass!2026" }
  end

  def json_access_token(email)
    post session_path(format: :json), params: { email: email, password: "StrongPass!2026" }
    response.parsed_body.fetch("access_token")
  end

  def pending_employee(overrides = {})
    email = "pending.#{SecureRandom.hex(4)}@example.test"
    User.create!(
      {
        firstname: "Pending",
        lastname: "Employee",
        email: email,
        mobile: "9876500012",
        password: "StrongPass!2026",
        user_type: "employee",
        current_site: @site,
        position: "Technician",
        active: false,
        is_admin_approved: false,
        user_status: false,
        registration_status: "pending",
        registration_submitted_at: Time.current
      }.merge(overrides)
    )
  end

  test "options lists active work locations without a session" do
    get public_employee_registration_options_path(format: :json)

    assert_response :success
    sites = response.parsed_body["sites"]
    departments = response.parsed_body["departments"]
    assert_equal [ @site.id ], sites.map { |site| site["id"] }
    assert_equal [ @department.id ], departments.map { |department| department["id"] }
    assert_equal 12, response.parsed_body["minimum_password_length"]
  end

  test "an employee can self-register and the account waits for approval" do
    params = registration_params

    assert_difference("User.count", 1) do
      post public_employee_registrations_path(format: :json), params: params
    end

    assert_response :created
    body = response.parsed_body
    assert_equal "pending", body.dig("employee", "registration_status")

    user = User.find_by!(email: params[:employee_registration][:email])
    assert_equal "employee", user.user_type
    assert_equal "pending", user.registration_status
    assert_not user.active?
    assert_not user.is_admin_approved?
    assert_nil user.role
    assert_equal @site.id, user.current_site_id
    assert_equal @department.id, user.department_id
    assert_equal "Facility Executive", user.position
    assert user.registration_submitted_at.present?
    assert_empty user.user_sites

    post session_path(format: :json), params: {
      email: user.email,
      password: "StrongPass!2026"
    }

    assert_response :forbidden
    assert_equal "registration_pending", response.parsed_body.dig("error", "code")
  end

  test "self-registration does not let a caller choose a privileged role or activate the account" do
    params = registration_params(
      role_id: @super_admin.role_id,
      user_type: "pms_admin",
      active: true,
      is_admin_approved: true,
      registration_status: "approved"
    )

    post public_employee_registrations_path(format: :json), params: params

    assert_response :created
    user = User.find_by!(email: params[:employee_registration][:email])
    assert_equal "employee", user.user_type
    assert_nil user.role_id
    assert_not user.active?
    assert_equal "pending", user.registration_status
    assert_not user.is_admin_approved?
  end

  test "self-registration rejects duplicate emails" do
    params = registration_params
    post public_employee_registrations_path(format: :json), params: params
    assert_response :created

    post public_employee_registrations_path(format: :json), params: params

    assert_response :unprocessable_entity
    assert_equal "registration_pending", response.parsed_body.dig("error", "code")
  end

  test "self-registration rejects a mismatched password confirmation" do
    post public_employee_registrations_path(format: :json),
         params: registration_params(password_confirmation: "DifferentPass!2026")

    assert_response :unprocessable_entity
    assert_equal "password_mismatch", response.parsed_body.dig("error", "code")
    assert_equal 0, User.where(user_type: "employee").where("email LIKE ?", "asha.employee.%").count
  end

  test "self-registration validates the password length and work location" do
    post public_employee_registrations_path(format: :json),
         params: registration_params(password: "short", password_confirmation: "short")

    assert_response :unprocessable_entity
    assert_equal "validation_failed", response.parsed_body.dig("error", "code")

    post public_employee_registrations_path(format: :json),
         params: registration_params(current_site_id: 0)

    assert_response :unprocessable_entity
    assert_equal "invalid_site", response.parsed_body.dig("error", "code")

    post public_employee_registrations_path(format: :json),
         params: registration_params(department_id: 0)

    assert_response :unprocessable_entity
    assert_equal "invalid_department", response.parsed_body.dig("error", "code")
  end

  test "admins can list and approve pending employee registrations" do
    employee = pending_employee
    token = json_access_token(@admin.email)

    get pending_registrations_users_path(format: :json),
        headers: { "Authorization" => "Bearer #{token}" }

    assert_response :success
    assert_equal [ employee.id ], response.parsed_body["data"].map { |user| user["id"] }

    sign_in(@admin.email)
    post approve_registration_user_path(employee)

    assert_redirected_to users_path
    employee.reload
    assert_equal "approved", employee.registration_status
    assert employee.active?
    assert employee.is_admin_approved?
    assert_equal @admin.id, employee.reviewed_by_id
    assert employee.reviewed_at.present?
    assert_equal "staff", employee.role_key

    post session_path(format: :json), params: {
      email: employee.email,
      password: "StrongPass!2026"
    }
    assert_response :success
    assert response.parsed_body["access_token"].present?
  end

  test "super admins can approve pending employee registrations" do
    employee = pending_employee
    sign_in(@super_admin.email)

    post approve_registration_user_path(employee)

    assert_redirected_to users_path
    employee.reload
    assert_equal "approved", employee.registration_status
    assert employee.active?
    assert_equal @super_admin.id, employee.reviewed_by_id
  end

  test "admins can reject a pending registration" do
    employee = pending_employee
    sign_in(@admin.email)

    post reject_registration_user_path(employee)

    assert_redirected_to users_path
    employee.reload
    assert_equal "rejected", employee.registration_status
    assert_not employee.active?
    assert_equal @admin.id, employee.reviewed_by_id

    post session_path(format: :json), params: {
      email: employee.email,
      password: "StrongPass!2026"
    }
    assert_response :forbidden
    assert_equal "registration_rejected", response.parsed_body.dig("error", "code")
  end

  test "users without user-management permissions cannot approve registrations" do
    employee = pending_employee
    sign_in(@security.email)

    post approve_registration_user_path(employee)

    assert_redirected_to root_path
    assert_equal "pending", employee.reload.registration_status
  end

  test "only pending registrations can be reviewed" do
    approved_employee = pending_employee(registration_status: "approved", active: true)
    sign_in(@admin.email)

    post approve_registration_user_path(approved_employee)

    assert_redirected_to root_path
  end

  test "an administrator cannot activate a pending employee without approving it" do
    employee = pending_employee
    sign_in(@admin.email)

    patch user_path(employee), params: { user: { active: true } }

    assert_response :unprocessable_entity
    assert_not employee.reload.active?
    assert_equal "pending", employee.registration_status
  end
end
