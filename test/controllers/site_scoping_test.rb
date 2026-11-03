require "test_helper"

# A user attached to a site must only see and change data for that site.
class SiteScopingTest < ActionDispatch::IntegrationTest
  PASSWORD = "StrongPass!2026".freeze

  def setup
    @site_a = Site.create!(name: "Alpha Campus", code: "ALPHA")
    @site_b = Site.create!(name: "Beta Campus", code: "BETA")

    @site_admin_role = Role.find_or_create_by!(key: "site_admin") do |role|
      role.name = "Site Admin"
      role.power_level = 80
    end
    grant_all_permissions(@site_admin_role)

    @admin = User.create!(
      firstname: "Site",
      lastname: "Admin",
      email: "site-admin@example.test",
      password: PASSWORD,
      role: @site_admin_role,
      current_site_id: @site_a.id
    )

    @super_admin_role = Role.find_or_create_by!(key: "super_admin") do |role|
      role.name = "Super Administrator"
      role.power_level = 100
      role.is_system = true
    end
    @super_admin = User.create!(
      firstname: "Super",
      lastname: "Admin",
      email: "super-admin-site@example.test",
      password: PASSWORD,
      role: @super_admin_role
    )

    @building_a = @site_a.buildings.create!(name: "Alpha Tower")
    @floor_a = @building_a.floors.create!(name: "Ground")
    @unit_a = @floor_a.units.create!(name: "A-101")

    @building_b = @site_b.buildings.create!(name: "Beta Tower")
    @floor_b = @building_b.floors.create!(name: "Ground")
    @unit_b = @floor_b.units.create!(name: "B-201")

    @visitor_a = Visitor.create!(name: "Alpha Guest", contact_no: "9876500101", site: @site_a)
    @visitor_b = Visitor.create!(name: "Beta Guest", contact_no: "9876500102", site: @site_b)

    @staff_a = Staff.create!(firstname: "Alpha", lastname: "Staff", mobile_no: "9876500103", site: @site_a)
    @staff_b = Staff.create!(firstname: "Beta", lastname: "Staff", mobile_no: "9876500104", site: @site_b)

    @resident_a = User.create!(
      firstname: "Alpha", lastname: "Resident", email: "alpha-resident@example.test",
      password: PASSWORD, current_site_id: @site_a.id
    )
    @resident_b = User.create!(
      firstname: "Beta", lastname: "Resident", email: "beta-resident@example.test",
      password: PASSWORD, current_site_id: @site_b.id
    )
  end

  def grant_all_permissions(role)
    Role::RESOURCES.each do |resource|
      resource[:actions].each do |action|
        role.permissions.find_or_create_by!(resource: resource[:key], action: action)
      end
    end
  end

  def headers_for(user)
    post session_path(format: :json), params: { email: user.email, password: PASSWORD }
    { "Authorization" => "Bearer #{response.parsed_body.fetch('access_token')}" }
  end

  test "scoped admin only sees visitors from their site" do
    get visitors_path(format: :json), headers: headers_for(@admin)

    assert_response :success
    names = response.parsed_body.fetch("visitors").map { |visitor| visitor.fetch("name") }
    assert_includes names, "Alpha Guest"
    assert_not_includes names, "Beta Guest"
  end

  test "scoped admin cannot open a visitor from another site" do
    get visitor_path(@visitor_b, format: :json), headers: headers_for(@admin)

    assert_response :not_found
    assert_equal "not_found", response.parsed_body.dig("error", "code")
  end

  test "scoped admin only sees their site, buildings, floors, units and staff" do
    headers = headers_for(@admin)

    get sites_path(format: :json), headers: headers
    site_ids = response.parsed_body.fetch("data").map { |site| site.fetch("id") }
    assert_equal [ @site_a.id ], site_ids

    get buildings_path(format: :json), headers: headers
    building_names = response.parsed_body.fetch("data").map { |building| building.fetch("name") }
    assert_equal [ "Alpha Tower" ], building_names

    get floors_path(format: :json), headers: headers
    floor_ids = response.parsed_body.fetch("data").map { |floor| floor.fetch("id") }
    assert_equal [ @floor_a.id ], floor_ids

    get units_path(format: :json), headers: headers
    unit_names = response.parsed_body.fetch("data").map { |unit| unit.fetch("name") }
    assert_equal [ "A-101" ], unit_names

    get staffs_path(format: :json), headers: headers
    staff_names = response.parsed_body.fetch("data").map { |staff| staff.fetch("firstname") }
    assert_equal [ "Alpha" ], staff_names
  end

  test "scoped admin only sees users attached to their site" do
    get users_path(format: :json), headers: headers_for(@admin)

    assert_response :success
    emails = response.parsed_body.fetch("data").map { |user| user.fetch("email") }
    assert_includes emails, @admin.email
    assert_includes emails, @resident_a.email
    assert_not_includes emails, @resident_b.email
    assert_not_includes emails, @super_admin.email
  end

  test "scoped admin cannot open a user from another site" do
    get user_path(@resident_b, format: :json), headers: headers_for(@admin)

    assert_response :not_found
    assert_equal "not_found", response.parsed_body.dig("error", "code")
  end

  test "dashboard metrics are scoped to the current site" do
    get root_path(format: :json), headers: headers_for(@admin)

    assert_response :success
    body = response.parsed_body
    assert_equal 1, body.fetch("sites_count")
    assert_equal 1, body.fetch("units_count")
    assert_equal 1, body.fetch("visitors_count")
    assert_equal 1, body.fetch("staffs_count")
    # The site admin and the Alpha resident belong to the site.
    assert_equal 2, body.fetch("users_count")
  end

  test "creating a visitor assigns the signed-in user as creator" do
    post visitors_path(format: :json),
         params: {
           visitor: {
             name: "New Alpha Guest", contact_no: "9876500105",
             # A spoofed creator must be ignored in favour of the session user.
             created_by_id: @super_admin.id,
             expected_date: Date.current.iso8601, expected_time: "10:00"
           }
         },
         headers: headers_for(@admin)

    assert_response :created
    body = response.parsed_body
    assert_equal @site_a.id, body.fetch("site_id")
    assert_equal @admin.id, body.fetch("created_by_id")
    assert_equal @admin.full_name, body.fetch("created_by_name")
  end

  test "a super admin from the same site can be selected as host" do
    @super_admin.update!(
      current_site_id: @site_a.id,
      building_id: @building_a.id,
      floor_id: @floor_a.id,
      unit_id: @unit_a.id
    )

    post visitors_path(format: :json),
         params: {
           visitor: {
             name: "Hosted By Super Admin", contact_no: "9876500111",
             site_id: @site_a.id, building_id: @building_a.id,
             floor_id: @floor_a.id, unit_id: @unit_a.id,
             vhost_id: @super_admin.id,
             expected_date: Date.current.iso8601, expected_time: "10:00"
           }
         },
         headers: headers_for(@admin)

    assert_response :created
    assert_equal @super_admin.id, response.parsed_body.fetch("vhost_id")
  end

  test "expected date and time are mandatory" do
    post visitors_path(format: :json),
         params: { visitor: { name: "No Time Guest", contact_no: "9876500109" } },
         headers: headers_for(@admin)

    assert_response :unprocessable_entity
    message = response.parsed_body.dig("error", "message")
    assert_includes message, "Expected date can't be blank"
    assert_includes message, "Expected time can't be blank"
  end

  test "employee visitor defaults come from their own profile" do
    employee_role = Role.find_or_create_by!(key: "staff") do |role|
      role.name = "Operations Staff"
      role.power_level = 30
      role.is_system = true
    end
    employee_role.permissions.find_or_create_by!(resource: "visitors", action: "create")

    employee = User.create!(
      firstname: "Default", lastname: "Employee",
      email: "default-employee@example.test",
      password: PASSWORD,
      role: employee_role,
      user_type: "employee",
      current_site_id: @site_a.id,
      building_id: @building_a.id,
      floor_id: @floor_a.id,
      unit_id: @unit_a.id
    )

    post visitors_path(format: :json),
         params: {
           visitor: {
             name: "Employee Guest", contact_no: "9876500110",
             expected_date: Date.current.iso8601, expected_time: "10:00"
           }
         },
         headers: headers_for(employee)

    assert_response :created
    body = response.parsed_body
    assert_equal @site_a.id, body.fetch("site_id")
    assert_equal @building_a.id, body.fetch("building_id")
    assert_equal @floor_a.id, body.fetch("floor_id")
    assert_equal @unit_a.id, body.fetch("unit_id")
    assert_equal employee.id, body.fetch("vhost_id")
  end

  test "scoped admin cannot create a visitor for another site" do
    post visitors_path(format: :json),
         params: { visitor: { name: "Wrong Site Guest", contact_no: "9876500106", site_id: @site_b.id } },
         headers: headers_for(@admin)

    assert_response :forbidden
    assert_equal "forbidden", response.parsed_body.dig("error", "code")
  end

  test "scoped admin cannot create a visitor against another site's unit" do
    post visitors_path(format: :json),
         params: { visitor: { name: "Wrong Unit Guest", contact_no: "9876500108", unit_id: @unit_b.id } },
         headers: headers_for(@admin)

    assert_response :forbidden
  end

  test "scoped admin cannot attach a residence at another site's unit" do
    post user_sites_path(format: :json),
         params: { user_site: { user_id: @resident_a.id, unit_id: @unit_b.id } },
         headers: headers_for(@admin)

    assert_response :forbidden
  end

  test "scoped admin cannot attach another site's resident to their own unit" do
    post user_sites_path(format: :json),
         params: { user_site: { user_id: @resident_b.id, unit_id: @unit_a.id } },
         headers: headers_for(@admin)

    assert_response :forbidden
  end

  test "creating a staff member assigns the current site" do
    post staffs_path(format: :json),
         params: { staff: { firstname: "New", lastname: "Guard", mobile_no: "9876500107" } },
         headers: headers_for(@admin)

    assert_response :created
    assert_equal @site_a.id, response.parsed_body.fetch("site_id")
  end

  test "creating a user assigns the current site" do
    post users_path(format: :json),
         params: {
           user: {
             firstname: "New", lastname: "Resident",
             email: "new-alpha-resident@example.test", password: PASSWORD
           }
         },
         headers: headers_for(@admin)

    assert_response :created
    assert_equal @site_a.id, response.parsed_body.fetch("current_site_id")
  end

  test "scoped admin cannot move a user to another site" do
    post users_path(format: :json),
         params: {
           user: {
             firstname: "Wrong", lastname: "Site",
             email: "wrong-site-resident@example.test", password: PASSWORD,
             current_site_id: @site_b.id
           }
         },
         headers: headers_for(@admin)

    assert_response :forbidden
  end

  test "departments belong to the current site" do
    headers = headers_for(@admin)

    post departments_path(format: :json),
         params: { department: { name: "Housekeeping" } },
         headers: headers

    assert_response :created
    assert_equal @site_a.id, response.parsed_body.fetch("site_id")

    Department.create!(name: "Beta Department", site: @site_b)
    Department.create!(name: "Legacy Department")

    get departments_path(format: :json), headers: headers
    names = response.parsed_body.fetch("data").map { |department| department.fetch("name") }
    assert_includes names, "Housekeeping"
    assert_includes names, "Legacy Department"
    assert_not_includes names, "Beta Department"
  end

  test "a user linked only through user_sites is still scoped and gets a working site" do
    linked = User.create!(
      firstname: "Linked", lastname: "Manager",
      email: "linked-manager@example.test",
      password: PASSWORD,
      role: @site_admin_role
    )
    UserSite.create!(user: linked, site: @site_a, is_primary: true)
    # Simulate legacy data where the denormalised current_site_id is missing.
    linked.update_columns(current_site_id: nil)

    assert_equal @site_a, linked.reload.working_site
    assert linked.site_restricted?

    get visitors_path(format: :json), headers: headers_for(linked)
    names = response.parsed_body.fetch("visitors").map { |visitor| visitor.fetch("name") }
    assert_includes names, "Alpha Guest"
    assert_not_includes names, "Beta Guest"
  end

  test "super admin still sees every site" do
    headers = headers_for(@super_admin)

    get visitors_path(format: :json), headers: headers
    names = response.parsed_body.fetch("visitors").map { |visitor| visitor.fetch("name") }
    assert_includes names, "Alpha Guest"
    assert_includes names, "Beta Guest"

    get sites_path(format: :json), headers: headers
    site_ids = response.parsed_body.fetch("data").map { |site| site.fetch("id") }
    assert_includes site_ids, @site_a.id
    assert_includes site_ids, @site_b.id
  end
end
