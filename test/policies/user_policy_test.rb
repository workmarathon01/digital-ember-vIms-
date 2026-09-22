require "test_helper"

class UserPolicyTest < ActiveSupport::TestCase
  def setup
    @admin = User.create!(firstname: "Admin", lastname: "One", email: "admin@example.test",
                          password: "StrongPass!2026", role: role("admin"))
    @security = User.create!(firstname: "Sec", lastname: "Two", email: "security@example.test",
                             password: "StrongPass!2026", role: role("security"))
  end

  def role(key)
    Role.find_or_create_by!(key: key) do |r|
      r.name = key.titleize
      r.power_level = key == "admin" ? 100 : 60
      r.is_system = true
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

  test "admin can manage everything" do
    policy = UserPolicy.new(@admin, User)
    assert policy.index?
    assert policy.create?
    assert policy.destroy?
    assert policy.lock?
    assert policy.unlock?
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
