class AddSuperAdminAndGateSecurityRoles < ActiveRecord::Migration[8.1]
  class MigrationRole < ActiveRecord::Base
    self.table_name = "roles"
  end

  class MigrationPermission < ActiveRecord::Base
    self.table_name = "permissions"
  end

  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  ADMIN_PERMISSIONS = {
    "users" => %w[read create update deactivate lock assign_roles],
    "features" => %w[read create update destroy],
    "site_features" => %w[read update],
    "user_features" => %w[read update],
    "sites" => %w[read create update destroy],
    "buildings" => %w[read create update destroy],
    "floors" => %w[read create update destroy],
    "units" => %w[read create update destroy],
    "user_sites" => %w[read create update destroy],
    "visitors" => %w[read create update destroy check_in check_out generate_otp export],
    "staffs" => %w[read create update destroy approve suspend attendance export],
    "roles" => %w[read],
    "audit_logs" => %w[read export]
  }.freeze

  GATE_SECURITY_PERMISSIONS = {
    "features" => %w[read],
    "site_features" => %w[read],
    "sites" => %w[read],
    "buildings" => %w[read],
    "floors" => %w[read],
    "units" => %w[read],
    "user_sites" => %w[read],
    "visitors" => %w[read create update check_in check_out generate_otp export],
    "staffs" => %w[read create update approve suspend attendance export],
    "audit_logs" => %w[read]
  }.freeze

  def up
    create_role("super_admin", "Super Administrator",
                "Unrestricted access to every module, role and permission.", 100)
    create_role("admin", "System Administrator",
                "Manages operations and users, but not roles or permissions.", 90)
    create_role("gate_security", "Gate Security",
                "Gate check-in for visitors and staff, including parking details.", 50)

    grant_permissions("admin", ADMIN_PERMISSIONS)
    grant_permissions("gate_security", GATE_SECURITY_PERMISSIONS)
    promote_first_admin!
  end

  def down
    MigrationRole.where(key: %w[super_admin gate_security]).destroy_all
  end

  private

  def create_role(key, name, description, power_level)
    role = MigrationRole.find_or_initialize_by(key: key)
    role.assign_attributes(
      name: name,
      description: description,
      power_level: power_level,
      is_system: true,
      active: true
    )
    role.save!
  end

  def grant_permissions(role_key, resources)
    role = MigrationRole.find_by!(key: role_key)
    resources.each do |resource, actions|
      actions.each do |action|
        MigrationPermission.find_or_create_by!(role_id: role.id, resource: resource, action: action)
      end
    end
  end

  # Ensure there is always an account that can manage roles after admin loses
  # the implicit all-access bypass.
  def promote_first_admin!
    super_admin = MigrationRole.find_by!(key: "super_admin")
    return if MigrationUser.where(role_id: super_admin.id).exists?

    admin = MigrationRole.find_by!(key: "admin")
    candidate = MigrationUser.where(role_id: admin.id).order(:id).first
    candidate&.update!(role_id: super_admin.id)
  end
end
