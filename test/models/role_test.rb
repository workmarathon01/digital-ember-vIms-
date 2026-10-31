require "test_helper"

class RoleTest < ActiveSupport::TestCase
  def setup
    @super_admin = Role.create!(name: "Super Administrator", key: "super_admin", power_level: 100, is_system: true)
    @admin = Role.create!(name: "System Administrator", key: "admin", power_level: 90, is_system: true)
    @admin.permissions.create!(resource: "visitors", action: "read")
    @clerk = Role.create!(name: "Front Desk", key: "front_desk", power_level: 40, is_system: false)
    @clerk.permissions.create!(resource: "visitors", action: "read")
    @clerk.permissions.create!(resource: "visitors", action: "check_in")
  end

  test "super admin can anything" do
    assert @super_admin.can?(:users, :create)
    assert @super_admin.can?(:roles, :permissions)
    assert @super_admin.super_admin?
    assert @super_admin.system?
  end

  test "admin only gets explicitly granted permissions" do
    assert @admin.can?(:visitors, :read)
    assert_not @admin.can?(:visitors, :destroy)
    assert_not @admin.can?(:roles, :permissions)
    assert @admin.admin?
    assert_not @admin.super_admin?
  end

  test "gate security is a system role" do
    role = Role.create!(name: "Gate Security", key: "gate_security", power_level: 50, is_system: true)

    assert role.system?
    assert role.gate_security?
  end

  test "role grants only configured permissions" do
    assert @clerk.can?(:visitors, :read)
    assert @clerk.can?(:visitors, :check_in)
    assert_not @clerk.can?(:visitors, :destroy)
    assert_not @clerk.can?(:staffs, :read)
  end

  test "key is normalized to parameterized underscore form" do
    role = Role.create!(name: "Back Office", key: "Back Office!", power_level: 20)
    assert_equal "back_office", role.key
  end

  test "system roles cannot collide on key" do
    duplicate = Role.new(name: "Super Clone", key: @super_admin.key)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:key], "has already been taken"
  end

  test "permission is unique per role resource action" do
    dup_perm = Permission.new(role: @clerk, resource: "visitors", action: "read")
    assert_not dup_perm.valid?
  end
end
