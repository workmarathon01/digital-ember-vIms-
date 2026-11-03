class NormalizeUserTypesAndSyncRoles < ActiveRecord::Migration[8.1]
  # `user_type` used to store the role name ("Gate Security") while `role_id`
  # stored the actual role. Standardise it to the role key ("gate_security")
  # and make the two fields agree for every existing account.
  def up
    execute <<~SQL.squish
      UPDATE users
      SET user_type = roles.key, updated_at = CURRENT_TIMESTAMP
      FROM roles
      WHERE users.user_type IS NOT NULL
        AND LOWER(TRIM(users.user_type)) = LOWER(roles.name)
        AND users.user_type <> roles.key
    SQL

    execute <<~SQL.squish
      UPDATE users
      SET user_type = REGEXP_REPLACE(LOWER(TRIM(user_type)), '\\s+', '_', 'g'),
          updated_at = CURRENT_TIMESTAMP
      WHERE user_type IS NOT NULL
        AND user_type <> ''
        AND user_type <> REGEXP_REPLACE(LOWER(TRIM(user_type)), '\\s+', '_', 'g')
    SQL

    execute <<~SQL.squish
      UPDATE users
      SET role_id = roles.id, updated_at = CURRENT_TIMESTAMP
      FROM roles
      WHERE users.user_type = roles.key
        AND users.role_id IS DISTINCT FROM roles.id
    SQL
  end

  # This is a one-way data normalisation; keep the cleaned values on rollback.
  def down; end
end
