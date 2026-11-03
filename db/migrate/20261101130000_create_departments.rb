class CreateDepartments < ActiveRecord::Migration[8.1]
  def up
    create_table :departments do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.text :description
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :departments, "LOWER(name)", unique: true,
              name: "index_departments_on_lower_name"
    add_index :departments, "LOWER(code)", unique: true,
              name: "index_departments_on_lower_code"
    add_index :users, :department_id

    # System administrators manage day-to-day setup data. Super admins bypass
    # permission checks, while other roles can be granted departments access
    # explicitly from Roles & Permissions.
    execute <<~SQL
      INSERT INTO permissions (role_id, resource, action, created_at, updated_at)
      SELECT roles.id, 'departments', actions.action, NOW(), NOW()
      FROM roles
      CROSS JOIN (VALUES ('read'), ('create'), ('update'), ('destroy')) AS actions(action)
      WHERE roles.key = 'admin'
      ON CONFLICT (role_id, resource, action) DO NOTHING
    SQL
  end

  def down
    execute "DELETE FROM permissions WHERE resource = 'departments'"
    remove_index :users, :department_id
    drop_table :departments
  end
end
