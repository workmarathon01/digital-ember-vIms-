require "test_helper"

class UserPolicyTest < ActiveSupport::TestCase
  def setup
    @super_admin = User.create!(firstname: "Super", lastname: "One", email: "super-admin@example.test",
                                password: "StrongPass!2026", role: role("super_admin", 100))
    @admin = User.create!(firstname: "Admin", lastname: "One", email: "admin@example.test",
                          password: "StrongPass!2026", role: role("admin", 90))
    seed_admin_permissions(@admin.role)
    @security = User.create!(firstname: "Sec", lastname: "Two", email: "security@example.test",
                             password: "StrongPass!2026", role: role("security", 60))
  end

  def role(key, level)
    Role.find_or_create_by!(key: key) do |r|
      r.name = key.titleize
      r.power_level = level
      r.is_system = true
    end
  end

  def seed_admin_permissions(role)
    Role::RESOURCES.each do |resource|
      actions = resource[:key] == "roles" ? %w[read] : resource[:actions]
      actions.each { |action| role.permissions.find_or_create_by!(resource: resource[:key], action: action) }
    end
  end

  def seed_default_permissions(role)
    {
      "users" => %w[read],
      "visitors" => %w[read create update check_in check_out generate_otp],
      "staffs" => %w[read approve suspend attendance]
    }.each do |resource, actions|
      actions.each { |action| role.permissions.find_or_create_by!(resource: resource, action: action) }
    end
  end

  test "super admin can manage everything" do
    policy = UserPolicy.new(@super_admin, User)
    assert policy.index?
    assert policy.create?
    assert policy.destroy?
    assert policy.lock?
    assert policy.unlock?
  end

  test "admin can manage users but not super admin accounts" do
    policy = UserPolicy.new(@admin, @super_admin)
    assert_not policy.show?
    assert_not policy.update?
    assert_not policy.destroy?
    assert_not policy.lock?
    assert_not policy.unlock?
  end

  test "admin only sees non-super-admin accounts" do
    scope = UserPolicy::Scope.new(@admin, User).resolve

    assert_includes scope, @admin
    assert_includes scope, @security
    assert_not_includes scope, @super_admin
  end

  test "security can read users but not create or destroy" do
    seed_default_permissions(@security.role)
    policy = UserPolicy.new(@security, User)

    assert policy.index?
    assert_not policy.create?
    assert_not policy.destroy?
    assert_not policy.lock?
  end

  test "user without permissions gets denied" do
    viewer = User.create!(firstname: "None", lastname: "Nobody", email: "none@example.test",
                          password: "StrongPass!2026")

    assert_not UserPolicy.new(viewer, User).index?
    assert_not VisitorPolicy.new(viewer, Visitor).index?
    assert_not StaffPolicy.new(viewer, Staff).approve?
  end

  test "a user may view their own profile" do
    policy = UserPolicy.new(@security, @security)
    assert policy.show?
  end
end
