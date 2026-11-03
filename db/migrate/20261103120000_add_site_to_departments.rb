class AddSiteToDepartments < ActiveRecord::Migration[8.1]
  def up
    add_reference :departments, :site, foreign_key: true, index: true

    # Department names/codes only need to be unique inside a site.
    remove_index :departments, name: "index_departments_on_lower_code"
    remove_index :departments, name: "index_departments_on_lower_name"

    add_index :departments, "site_id, lower(code)", unique: true,
              name: "index_departments_on_site_id_and_lower_code"
    add_index :departments, "site_id, lower(name)", unique: true,
              name: "index_departments_on_site_id_and_lower_name"
  end

  def down
    remove_index :departments, name: "index_departments_on_site_id_and_lower_code"
    remove_index :departments, name: "index_departments_on_site_id_and_lower_name"

    add_index :departments, "lower(code)", unique: true,
              name: "index_departments_on_lower_code"
    add_index :departments, "lower(name)", unique: true,
              name: "index_departments_on_lower_name"

    remove_reference :departments, :site, foreign_key: true
  end
end
