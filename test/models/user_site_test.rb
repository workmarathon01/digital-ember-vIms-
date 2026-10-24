require "test_helper"

class UserSiteTest < ActiveSupport::TestCase
  def setup
    @site = Site.create!(name: "Lakeview", code: "LAKEVIEW")
    @building = @site.buildings.create!(name: "Block B")
    @floor = @building.floors.create!(name: "2nd Floor")
    @unit = @floor.units.create!(name: "B-201")
    @other_unit = @floor.units.create!(name: "B-202")
    @user = User.create!(firstname: "Asha", lastname: "Resident", email: "asha@example.test",
                         password: "StrongPass!2026")
  end

  test "derives the full location from the unit" do
    association = UserSite.create!(user: @user, site: @site, unit: @unit,
                                   ownership: "tenant", is_primary: true)

    assert_equal @site.id, association.site_id
    assert_equal @building.id, association.building_id
    assert_equal @floor.id, association.floor_id
    assert_equal "Lakeview / Block B / 2nd Floor / B-201", association.location_label
  end

  test "a primary association syncs the user's legacy residence columns" do
    UserSite.create!(user: @user, site: @site, unit: @unit, ownership: "owner", is_primary: true)

    @user.reload
    assert_equal @site.id, @user.current_site_id
    assert_equal @building.id, @user.building_id
    assert_equal @floor.id, @user.floor_id
    assert_equal @unit.id, @user.unit_id
  end

  test "creating a new primary demotes the previous primary" do
    first = UserSite.create!(user: @user, site: @site, unit: @unit, ownership: "owner", is_primary: true)
    second = UserSite.create!(user: @user, site: @site, unit: @other_unit, ownership: "owner", is_primary: true)

    assert_not first.reload.is_primary?
    assert_predicate second, :is_primary?
    assert_equal @other_unit.id, @user.reload.unit_id
  end

  test "the same unit cannot be assigned twice to one resident" do
    UserSite.create!(user: @user, site: @site, unit: @unit, ownership: "owner")

    duplicate = UserSite.new(user: @user, site: @site, unit: @unit, ownership: "tenant")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:unit_id], "is already associated with this resident"
  end

  test "a site-only association is allowed" do
    association = UserSite.create!(user: @user, site: @site, ownership: "member")
    assert_predicate association, :persisted?
    assert_nil association.unit_id
  end

  test "destroying the primary promotes another association" do
    primary = UserSite.create!(user: @user, site: @site, unit: @unit, ownership: "owner", is_primary: true)
    secondary = UserSite.create!(user: @user, site: @site, unit: @other_unit, ownership: "family")

    primary.destroy!

    assert secondary.reload.is_primary?
    assert_equal @other_unit.id, @user.reload.unit_id
  end
end
