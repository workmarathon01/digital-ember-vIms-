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
    "visitors" => %w[read create update destroy check_in check_out generate_otp export],
    "staffs"   => %w[read create update destroy approve suspend attendance export],
    "audit_logs" => %w[read]
  },
  staff: {
    "visitors" => %w[read check_in check_out],
    "staffs"   => %w[read attendance]
  },
  resident: {
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
# Admin / demo accounts
# ══════════════════════════════════════════════════════════════════════════

admin = User.find_or_initialize_by(email: "admin@lect-and-nect.test")
admin.assign_attributes(
  firstname: "System",
  lastname: "Admin",
  role: roles.fetch("admin"),
  active: true,
  password: "ChangeMeNow!2026"
)
admin.save!

security = User.find_or_initialize_by(email: "security@lect-and-nect.test")
security.assign_attributes(
  firstname: "Security",
  lastname: "Desk",
  role: roles.fetch("security"),
  active: true,
  password: "ChangeMeNow!2026"
)
security.save!

Visitor.find_or_create_by!(contact_no: "9000000001") do |visitor|
  visitor.name = "Aarav Visitor"
  visitor.purpose = "Meeting"
  visitor.site_id = 1
  visitor.visit_type = "Guest"
  visitor.expected_date = Date.current
  visitor.expected_time = Time.current
  visitor.created_by = admin
end

Staff.find_or_create_by!(mobile_no: "9000000002", site_id: 1,
                         firstname: "Meera", lastname: "Staff", email: "meera.staff@example.test",
                         work_type: "Housekeeping", status_type: "Approved", created_by: admin)

puts "Seed complete: #{Role.count} roles, #{Permission.count} permissions, #{User.count} users."
