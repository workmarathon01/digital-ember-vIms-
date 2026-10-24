require "test_helper"

class PropertyHierarchyTest < ActiveSupport::TestCase
  def setup
    @site = Site.create!(name: "Riverside Campus", code: "RIVERSIDE", region: "West", city: "Pune")
    @building = @site.buildings.create!(name: "Tower A")
    @floor = @building.floors.create!(name: "4th Floor")
    @unit = @floor.units.create!(name: "A-401", unit_type: "2BHK", carpet_area: 980)
  end

  test "site without a code receives a generated unique code" do
    site = Site.create!(name: "Auto Coded Site")

    assert_match(/\ASITE-[A-Z0-9]{5}\z/, site.code)
  end

  test "floor and unit inherit their parents" do
    assert_equal @site.id, @floor.site_id
    assert_equal @building.id, @unit.building_id
    assert_equal @site.id, @unit.site_id
    assert_equal "4th Floor", @floor.name
    assert_equal 4, @floor.level
  end

  test "unit names are unique per floor but reusable across floors" do
    duplicate = @floor.units.new(name: "A-401")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"

    other_floor = @building.floors.create!(name: "5th Floor")
    assert other_floor.units.create!(name: "A-401").persisted?
  end

  test "site exposes its descendants through the hierarchy" do
    assert_equal 1, @site.buildings.size
    assert_equal 1, @site.floors.size
    assert_equal 1, @site.units.size
    assert_equal "Riverside Campus / Tower A / 4th Floor / A-401", @unit.location_label
  end

  test "unit occupancy reflects resident associations" do
    user = User.create!(firstname: "Resident", lastname: "One", email: "resident-one@example.test",
                        password: "StrongPass!2026")

    assert_not @unit.occupied?
    UserSite.create!(user: user, site: @site, unit: @unit, ownership: "owner", is_primary: true)
    assert @unit.reload.occupied?
    assert_includes Unit.occupied, @unit
  end

  test "sites with residents cannot be deleted" do
    user = User.create!(firstname: "Resident", lastname: "Two", email: "resident-two@example.test",
                        password: "StrongPass!2026")
    UserSite.create!(user: user, site: @site, unit: @unit, ownership: "tenant")

    assert_not @site.destroy
    assert_match(/resident/i, @site.errors.full_messages.to_sentence)
  end
end
