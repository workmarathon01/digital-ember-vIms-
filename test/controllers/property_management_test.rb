require "test_helper"

class PropertyManagementTest < ActionDispatch::IntegrationTest
  PASSWORD = "StrongPass!2026".freeze

  def setup
    @admin_role = Role.find_or_create_by!(key: "admin") do |role|
      role.name = "System Administrator"
      role.power_level = 100
      role.is_system = true
    end

    @admin = User.create!(
      firstname: "Property",
      lastname: "Admin",
      email: "property-admin@example.test",
      password: PASSWORD,
      role: @admin_role
    )

    @resident = User.create!(
      firstname: "Riya",
      lastname: "Resident",
      email: "riya-resident@example.test",
      password: PASSWORD
    )
  end

  def sign_in_html
    post session_path, params: { email: @admin.email, password: PASSWORD }
  end

  def sign_in_json(user = @admin)
    post session_path(format: :json), params: { email: user.email, password: PASSWORD }
    response.parsed_body.fetch("access_token")
  end

  def auth_headers(user = @admin)
    { "Authorization" => "Bearer #{sign_in_json(user)}" }
  end

  test "admin can build and browse the full hierarchy" do
    sign_in_html

    get sites_path
    assert_response :success

    post sites_path, params: { site: { name: "North Campus", code: "NORTH", city: "Delhi" } }
    site = Site.last
    assert_redirected_to site_path(site)

    post buildings_path, params: { building: { site_id: site.id, name: "Tower One" } }
    building = site.buildings.last
    assert_redirected_to building_path(building)

    post floors_path, params: { floor: { building_id: building.id, name: "3rd Floor" } }
    floor = building.floors.last
    assert_redirected_to floor_path(floor)

    post units_path, params: { unit: { floor_id: floor.id, name: "301", unit_type: "2BHK" } }
    unit = floor.units.last
    assert_redirected_to unit_path(unit)

    get site_path(site)
    assert_response :success
    assert_match "Tower One", response.body

    get unit_path(unit)
    assert_response :success
    assert_match "301", response.body
  end

  test "json api creates a unit and associates a resident" do
    headers = auth_headers

    post sites_path(format: :json), params: { site: { name: "East Campus", code: "EAST" } }, headers: headers
    assert_response :created
    site_id = response.parsed_body.fetch("id")

    post buildings_path(format: :json), params: { building: { site_id: site_id, name: "Block C" } }, headers: headers
    assert_response :created
    building_id = response.parsed_body.fetch("id")

    post floors_path(format: :json), params: { floor: { building_id: building_id, name: "Ground" } }, headers: headers
    assert_response :created
    floor_id = response.parsed_body.fetch("id")

    post units_path(format: :json), params: { unit: { floor_id: floor_id, name: "C-01" } }, headers: headers
    assert_response :created
    unit_id = response.parsed_body.fetch("id")

    post user_sites_path(format: :json), params: {
      user_site: { user_id: @resident.id, unit_id: unit_id, ownership: "owner", is_primary: true }
    }, headers: headers
    assert_response :created
    assert_equal "C-01", response.parsed_body.fetch("unit_name")

    @resident.reload
    assert_equal site_id, @resident.current_site_id
    assert_equal building_id, @resident.building_id
    assert_equal floor_id, @resident.floor_id
    assert_equal unit_id, @resident.unit_id

    get user_path(@resident, format: :json), headers: headers
    assert_response :success
    assert_equal 1, response.parsed_body.fetch("user_sites").size
  end

  test "property indexes render json for the frontend" do
    headers = auth_headers

    get sites_path(format: :json), headers: headers
    assert_response :success
    assert response.parsed_body.key?("data")
    assert response.parsed_body.key?("meta")

    get buildings_path(format: :json), headers: headers
    assert_response :success

    get floors_path(format: :json), headers: headers
    assert_response :success

    get units_path(format: :json), headers: headers
    assert_response :success

    get user_sites_path(format: :json), headers: headers
    assert_response :success
  end

  test "a user without property permissions is forbidden from JSON writes" do
    viewer_role = Role.create!(name: "Viewer", key: "viewer", power_level: 5)
    viewer = User.create!(
      firstname: "Viewer",
      lastname: "Only",
      email: "viewer@example.test",
      password: PASSWORD,
      role: viewer_role
    )

    post sites_path(format: :json), params: { site: { name: "Forbidden Site" } },
         headers: auth_headers(viewer)

    assert_response :forbidden
    assert_equal "forbidden", response.parsed_body.dig("error", "code")
  end

  test "deleting a site with residents is refused" do
    site = Site.create!(name: "Occupied Site", code: "OCCUPIED")
    building = site.buildings.create!(name: "Tower X")
    floor = building.floors.create!(name: "1st Floor")
    unit = floor.units.create!(name: "X-1")
    UserSite.create!(user: @resident, site: site, unit: unit, ownership: "owner")

    sign_in_html
    delete site_path(site)

    assert_redirected_to site_path(site)
    assert Site.exists?(site.id)
    assert_match(/resident/i, flash[:alert])
  end

  test "deleting an empty site over JSON returns no content" do
    site = Site.create!(name: "Empty JSON Site", code: "EMPTYJSON")

    delete site_path(site, format: :json), headers: auth_headers

    assert_response :no_content
    assert_not Site.exists?(site.id)
  end

  test "deleting an occupied site over JSON returns a delete_blocked error" do
    site = Site.create!(name: "Occupied JSON Site", code: "OCCJSON")
    building = site.buildings.create!(name: "Tower J")
    floor = building.floors.create!(name: "2nd Floor")
    unit = floor.units.create!(name: "J-2")
    UserSite.create!(user: @resident, site: site, unit: unit, ownership: "tenant")

    delete site_path(site, format: :json), headers: auth_headers

    assert_response :unprocessable_entity
    assert_equal "delete_blocked", response.parsed_body.dig("error", "code")
    assert Site.exists?(site.id)
  end

  test "creating a user with a unit creates the primary residence" do
    site = Site.create!(name: "New User Site", code: "NEWUSER")
    building = site.buildings.create!(name: "Tower N")
    floor = building.floors.create!(name: "Ground")
    unit = floor.units.create!(name: "N-01")

    sign_in_html
    post users_path, params: {
      user: {
        firstname: "New", lastname: "Resident", email: "new-resident@example.test",
        password: PASSWORD, unit_id: unit.id, role_id: @admin_role.id
      }
    }

    user = User.find_by(email: "new-resident@example.test")
    assert_redirected_to user_path(user)
    assert_equal 1, user.user_sites.count
    assert_predicate user.primary_user_site, :present?
    assert_equal unit.id, user.unit_id
  end
end
