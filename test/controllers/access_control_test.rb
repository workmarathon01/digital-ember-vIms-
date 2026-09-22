require "test_helper"

class AccessControlTest < ActionDispatch::IntegrationTest
  def setup
    @admin = create_role_and_user(:admin, "Admin User", "admin@example.test", 100)
    @security = create_role_and_user(:security, "Security User", "security@example.test", 60)
  end

  def create_role_and_user(key, name, email, level)
    role = Role.find_or_create_by!(key: key) do |r|
      r.name = name
      r.power_level = level
      r.is_system = true
    end
    if key == :security
      %w[read].each { |a| role.permissions.find_or_create_by!(resource: "visitors", action: a) }
    end
    User.create!(
      firstname: name.split.first,
      lastname: "Tester",
      email: email,
      password: "StrongPass!2026",
      role: role
    )
  end

  def sign_in(email)
    post session_path, params: { email: email, password: "StrongPass!2026" }
  end

  test "redirects anonymous users to sign in" do
    get visitors_path

    assert_redirected_to new_session_path
  end

  test "security user can view visitors but not users" do
    sign_in(@security.email)

    get visitors_path
    assert_response :success

    get users_path
    assert_redirected_to root_path
  end

  test "admin user can view users and roles" do
    sign_in(@admin.email)

    get users_path
    assert_response :success

    get roles_path
    assert_response :success

    get audit_logs_path
    assert_response :success
  end

  test "denied access is redirected and reported via flash" do
    sign_in(@security.email)

    get roles_path
    assert_redirected_to root_path
    assert_equal "You are not authorized to perform that action.", flash[:alert]
  end

  test "account locks after repeated failed logins" do
    user = @security
    User::MAX_FAILED_ATTEMPTS.times do
      post session_path, params: { email: user.email, password: "wrong-password" }
    end

    user.reload
    assert user.locked_out?, "user should be locked after repeated failures"

    post session_path, params: { email: user.email, password: "StrongPass!2026" }
    assert_redirected_to new_session_path
    assert_match(/Account locked/, flash[:alert])
  end

  test "admin can flow through dashboard, roles, users and visitors" do
    sign_in(@admin.email)

    get root_path
    assert_response :success

    visitor = Visitor.create!(name: "Demo Guest", contact_no: "9876500001", created_by: @admin)
    get users_path
    assert_response :success
    get visitors_path
    assert_response :success

    role = Role.create!(name: "Concierge", key: "concierge", power_level: 50)
    get roles_path
    assert_response :success
    get role_path(role)
    assert_response :success

    get user_path(@security)
    assert_response :success
  end

  test "visitor pass lifecycle with otp check-in" do
    sign_in(@admin.email)

    post visitors_path, params: { visitor: { name: "Priya Guest", contact_no: "9876500002", purpose: "Meeting" } }
    assert_redirected_to visitor_path(Visitor.last)
    visitor = Visitor.last
    assert_match(/\APASS-[A-Z0-9]{8}\z/, visitor.pass_code)

    raw_otp = visitor.generate_otp!
    post check_in_visitor_path(visitor), params: { otp: raw_otp }
    assert_redirected_to visitor_path(visitor)
    assert_equal "IN", visitor.reload.visitor_in_out

    post check_out_visitor_path(visitor)
    assert_equal "OUT", visitor.reload.visitor_in_out
  end

  test "role permission matrix is rebuilt on update" do
    sign_in(@admin.email)

    role = Role.create!(name: "Guard", key: "guard_custom", power_level: 40)
    put role_path(role), params: {
      role: { name: "Perimeter Guard" },
      permissions: { "visitors:read" => "1", "visitors:check_in" => "1", "staffs:read" => "0" }
    }
    assert_redirected_to role_path(role)

    role.reload
    assert role.can?(:visitors, :read)
    assert role.can?(:visitors, :check_in)
    assert_not role.can?(:staffs, :read)
  end

  test "staff approval and attendance punch lifecycle" do
    sign_in(@admin.email)

    post staffs_path, params: {
      staff: { firstname: "Ravi", lastname: "Worker", mobile_no: "9876500003",
               site_id: 1, work_type: "Technician" }
    }
    staff = Staff.last
    assert_redirected_to staff_path(staff)
    assert_equal "Pending", staff.status_type

    post approve_staff_path(staff)
    assert_equal "Approved", staff.reload.status_type

    post punch_in_staff_path(staff)
    assert_predicate staff.open_attendance, :present?

    post punch_out_staff_path(staff)
    assert_nil staff.reload.open_attendance
  end
end
