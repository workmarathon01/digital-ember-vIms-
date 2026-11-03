# ══════════════════════════════════════════════════════════════════════════
# RBAC roles & permissions
# ══════════════════════════════════════════════════════════════════════════

system_roles = {
  super_admin:   { name: "Super Administrator", description: "Unrestricted access to every module, role and permission.", power_level: 100 },
  admin:         { name: "System Administrator", description: "Manages operations and users, but not roles or permissions.", power_level: 90 },
  security:      { name: "Security Desk",        description: "Manages visitor passes and on-site staff.", power_level: 60 },
  gate_security: { name: "Gate Security",        description: "Gate check-in for visitors and staff, including parking details.", power_level: 50 },
  staff:         { name: "Operations Staff",     description: "Everyday visitor management and own attendance.", power_level: 30 },
  resident:      { name: "Resident",             description: "Self-service visitor invites for residents.", power_level: 10 }
}

all_actions = Role::RESOURCES.to_h { |resource| [ resource[:key], resource[:actions] ] }

admin_permissions = all_actions.merge(
  # Admins run day-to-day operations and manage users, but role and
  # permission changes belong to super admins only.
  "roles" => %w[read]
)

granted_permissions = {
  admin: admin_permissions,
  security: {
    "users"    => %w[read],
    "features" => %w[read],
    "site_features" => %w[read],
    "user_features" => %w[read],
    "sites"    => %w[read],
    "buildings" => %w[read],
    "floors"   => %w[read],
    "units"    => %w[read],
    "user_sites" => %w[read],
    "visitors" => %w[read create update destroy check_in check_out generate_otp export],
    "staffs"   => %w[read create update destroy approve suspend attendance export],
    "audit_logs" => %w[read]
  },
  gate_security: {
    "features" => %w[read],
    "site_features" => %w[read],
    "sites"    => %w[read],
    "buildings" => %w[read],
    "floors"   => %w[read],
    "units"    => %w[read],
    "user_sites" => %w[read],
    "visitors" => %w[read create update check_in check_out generate_otp export],
    "staffs"   => %w[read create update approve suspend attendance export],
    "audit_logs" => %w[read]
  },
  staff: {
    "features" => %w[read],
    "sites"    => %w[read],
    "buildings" => %w[read],
    "floors"   => %w[read],
    "units"    => %w[read],
    "visitors" => %w[read create update destroy check_in check_out generate_otp export],
    "staffs"   => %w[read attendance]
  },
  resident: {
    "features" => %w[read],
    "user_features" => %w[read],
    "sites"    => %w[read],
    "buildings" => %w[read],
    "floors"   => %w[read],
    "units"    => %w[read],
    "visitors" => %w[read create]
  }
}

roles = system_roles.map do |key, attrs|
  Role.find_or_initialize_by(key: key).tap do |role|
    role.assign_attributes(
      name: attrs[:name],
      description: attrs[:description],
      power_level: attrs[:power_level],
      is_system: true,
      active: true
    )
    role.save!
  end
end.each_with_object({}) { |r, memo| memo[r.key] = r }

granted_permissions.each do |role_key, resources|
  role = roles.fetch(role_key.to_s, nil)
  next unless role

  resources.each do |resource, actions|
    actions.each do |action|
      Permission.find_or_create_by!(role: role, resource: resource, action: action)
    end
  end
end

# ══════════════════════════════════════════════════════════════════════════
# Demo property hierarchy
# ══════════════════════════════════════════════════════════════════════════

demo_site = Site.find_or_initialize_by(code: "DEMO01")
demo_site.assign_attributes(
  name: "Demo Campus",
  region: "West",
  city: "Pune",
  state: "Maharashtra",
  country: "India",
  timezone: "Asia/Kolkata",
  active: true,
  description: "Seed data for the site → building → floor → unit hierarchy."
)
demo_site.save!

demo_building = demo_site.buildings.find_or_initialize_by(name: "Tower A")
demo_building.assign_attributes(code: "TOWER-A", description: "Residential tower")
demo_building.save!

demo_floor = demo_building.floors.find_or_initialize_by(name: "Ground Floor")
demo_floor.assign_attributes(level: 0)
demo_floor.save!

demo_unit = demo_floor.units.find_or_initialize_by(name: "A-101")
demo_unit.assign_attributes(unit_type: "2BHK", carpet_area: 980, status: "active")
demo_unit.save!

second_unit = demo_floor.units.find_or_initialize_by(name: "A-102")
second_unit.assign_attributes(unit_type: "3BHK", carpet_area: 1240, status: "active")
second_unit.save!

# ══════════════════════════════════════════════════════════════════════════
# Feature catalog
# ══════════════════════════════════════════════════════════════════════════

feature_catalog = Feature::STANDARD_TEMPLATES

features = feature_catalog.map do |attrs|
  Feature.find_or_initialize_by(key: attrs[:key]).tap do |feature|
    feature.assign_attributes(attrs.merge(active: true))
    feature.save!
  end
end

# ══════════════════════════════════════════════════════════════════════════
# Admin / demo accounts
# ══════════════════════════════════════════════════════════════════════════

admin = User.find_or_initialize_by(email: "admin@lect-and-nect.test")
admin.assign_attributes(
  firstname: "System",
  lastname: "Admin",
  role: roles.fetch("admin"),
  active: true,
  password: "ChangeMeNow!2026",
  current_site_id: demo_site.id,
  building_id: demo_building.id,
  floor_id: demo_floor.id,
  unit_id: demo_unit.id
)
admin.save!

super_admin = User.find_or_initialize_by(email: "superadmin@lect-and-nect.test")
super_admin.assign_attributes(
  firstname: "Super",
  lastname: "Admin",
  role: roles.fetch("super_admin"),
  active: true,
  password: "ChangeMeNow!2026",
  current_site_id: demo_site.id
)
super_admin.save!

gate_security = User.find_or_initialize_by(email: "gate.security@lect-and-nect.test")
gate_security.assign_attributes(
  firstname: "Gate",
  lastname: "Security",
  role: roles.fetch("gate_security"),
  active: true,
  password: "ChangeMeNow!2026",
  current_site_id: demo_site.id
)
gate_security.save!

demo_site.sync_features!(features.select(&:default_enabled).map(&:id), actor: super_admin)

if admin.user_sites.empty?
  admin.user_sites.create!(
    site: demo_site,
    building: demo_building,
    floor: demo_floor,
    unit: demo_unit,
    ownership: "owner",
    is_primary: true,
    lives_here: true,
    is_approved: true,
    move_in_date: Date.current
  )
end

security = User.find_or_initialize_by(email: "security@lect-and-nect.test")
security.assign_attributes(
  firstname: "Security",
  lastname: "Desk",
  role: roles.fetch("security"),
  active: true,
  password: "ChangeMeNow!2026",
  current_site_id: demo_site.id
)
security.save!

visitor = Visitor.find_or_initialize_by(contact_no: "9000000001")
visitor.assign_attributes(
  name: "Aarav Visitor",
  purpose: "Meeting",
  site_id: demo_site.id,
  building_id: demo_building.id,
  floor_id: demo_floor.id,
  unit_id: demo_unit.id,
  visit_type: "Guest",
  expected_date: Date.current,
  expected_time: Time.current,
  created_by: admin
)
visitor.save!

staff = Staff.find_or_initialize_by(mobile_no: "9000000002")
staff.assign_attributes(
  firstname: "Meera",
  lastname: "Staff",
  email: "meera.staff@example.test",
  work_type: "Housekeeping",
  status_type: "Approved",
  site_id: demo_site.id,
  unit_id: demo_unit.id,
  created_by: admin
)
staff.save!

puts "Seed complete: #{Role.count} roles, #{Permission.count} permissions, #{User.count} users, " \
     "#{Site.count} sites, #{Building.count} buildings, #{Floor.count} floors, #{Unit.count} units, " \
     "#{Feature.count} features, #{SiteFeature.count} site feature entitlements."
