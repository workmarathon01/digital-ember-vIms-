class GrantFullVisitorAccessToStaffRole < ActiveRecord::Migration[8.1]
  # Employees approved from the public onboarding flow get the `staff` role.
  # They need the full visitor module so they can invite and manage their own
  # site's visitors, not only check them in and out.
  VISITOR_ACTIONS = %w[read create update destroy check_in check_out generate_otp export].freeze

  def up
    role_id = staff_role_id
    return if role_id.blank?

    VISITOR_ACTIONS.each do |action|
      execute <<~SQL.squish
        INSERT INTO permissions (role_id, resource, action, created_at, updated_at)
        SELECT #{role_id.to_i}, 'visitors', #{connection.quote(action)},
               CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        WHERE NOT EXISTS (
          SELECT 1 FROM permissions
          WHERE role_id = #{role_id.to_i}
            AND resource = 'visitors'
            AND action = #{connection.quote(action)}
        )
      SQL
    end
  end

  def down
    role_id = staff_role_id
    return if role_id.blank?

    execute <<~SQL.squish
      DELETE FROM permissions
      WHERE role_id = #{role_id.to_i}
        AND resource = 'visitors'
        AND action IN ('create', 'update', 'destroy', 'generate_otp', 'export')
    SQL
  end

  private

  def staff_role_id
    select_value("SELECT id FROM roles WHERE key = 'staff' LIMIT 1")
  end
end
