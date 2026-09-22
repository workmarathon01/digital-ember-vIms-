require "test_helper"

class RoleTest < ActiveSupport::TestCase
  def setup
    @admin = Role.create!(name: "System Administrator", key: "admin", power_level: 100, is_system: true)
    @clerk = Role.create!(name: "Front Desk", key: "front_desk", power_level: 40, is_system: false)
    @clerk.permissions.create!(resource: "visitors", action: "read")
    @clerk.permissions.create!(resource: "visitors", action: "check_in")
  end

  test "super admin can anything" do
    assert @admin.can?(:users, :create)
    assert @admin.can?(:roles, :permissions)
    assert @admin.super_admin?
    assert @admin.system?
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
    duplicate = Role.new(name: "Super Clone", key: @admin.key)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:key], "has already been taken"
  end

  test "permission is unique per role resource action" do
    dup_perm = Permission.new(role: @clerk, resource: "visitors", action: "read")
    assert_not dup_perm.valid?
  end
end
