# ══════════════════════════════════════════════════════════════════════════
# RBAC roles & permissions
# ══════════════════════════════════════════════════════════════════════════

system_roles = {
  admin:    { name: "System Administrator", description: "Unrestricted access to every module.", power_level: 100 },
  security: { name: "Security Desk",        description: "Manages visitor passes and on-site staff.", power_level: 60 },
  staff:    { name: "Operations Staff",     description: "Everyday visitor check-in and own attendance.", power_level: 30 },
  resident: { name: "Resident",             description: "Self-service visitor invites for residents.", power_level: 10 }
}

granted_permissions = {
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
  staff: {
    "features" => %w[read],
    "sites"    => %w[read],
    "buildings" => %w[read],
    "floors"   => %w[read],
    "units"    => %w[read],
    "visitors" => %w[read check_in check_out],
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

feature_catalog = [
  { key: "visitor_management", name: "Visitor Management", category: "operations", icon: "clipboard-list",
    sort_order: 10, default_enabled: true,
    description: "Pre-registration, gate passes, OTP check-in and visitor history." },
  { key: "staff_management", name: "Staff Management", category: "operations", icon: "users",
    sort_order: 20, default_enabled: true,
    description: "Staff directory, approvals, shifts and attendance." },
  { key: "property_management", name: "Properties & Residents", category: "operations", icon: "building",
    sort_order: 30, default_enabled: true,
    description: "Site, building, floor and unit hierarchy with resident associations." },
  { key: "gate_passes", name: "Gate Passes & OTP", category: "security", icon: "key-round",
    sort_order: 40, default_enabled: true,
    description: "Pass-code and OTP verification for gate operations." },
  { key: "kiosk_mode", name: "Kiosk Check-in", category: "security", icon: "monitor-smartphone",
    sort_order: 50, default_enabled: true,
    description: "Self-service visitor check-in at a shared kiosk." },
  { key: "audit_trail", name: "Audit Trail", category: "platform", icon: "scroll-text",
    sort_order: 60, default_enabled: true,
    description: "Immutable activity history for security and compliance." },
  { key: "reports", name: "Reports & Analytics", category: "reporting", icon: "bar-chart",
    sort_order: 70, default_enabled: true,
    description: "Operational reporting and occupancy insights." },
  { key: "user_management", name: "Users & Roles", category: "platform", icon: "user-cog",
    sort_order: 80, default_enabled: true,
    description: "User accounts, role assignments and access control." }
]

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

demo_site.sync_features!(features.select(&:default_enabled).map(&:id), actor: admin)

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
  password: "ChangeMeNow!2026"
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
