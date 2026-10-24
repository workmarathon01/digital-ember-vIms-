class CreatePropertyHierarchy < ActiveRecord::Migration[8.1]
  def change
    create_table :sites do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.string :region
      t.string :address
      t.string :city
      t.string :state
      t.string :country, default: "India"
      t.string :postal_code
      t.string :timezone
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.boolean :active, null: false, default: true
      t.text :description
      t.timestamps
    end

    add_index :sites, :code, unique: true
    add_index :sites, :active
    add_index :sites, :name

    create_table :buildings do |t|
      t.references :site, null: false, foreign_key: true
      t.string :name, null: false
      t.string :code
      t.text :description
      t.timestamps
    end

    add_index :buildings, [ :site_id, :name ], unique: true
    add_index :buildings, :code

    create_table :floors do |t|
      t.references :site, null: false, foreign_key: true
      t.references :building, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :level
      t.text :description
      t.timestamps
    end

    add_index :floors, [ :building_id, :name ], unique: true
    add_index :floors, :level

    create_table :units do |t|
      t.references :site, null: false, foreign_key: true
      t.references :building, null: false, foreign_key: true
      t.references :floor, null: false, foreign_key: true
      t.string :name, null: false
      t.string :unit_type
      t.decimal :carpet_area, precision: 10, scale: 2
      t.string :status, null: false, default: "active"
      t.text :description
      t.timestamps
    end

    add_index :units, [ :floor_id, :name ], unique: true
    add_index :units, :status
    add_index :units, :unit_type

    create_table :user_sites do |t|
      t.references :user, null: false, foreign_key: true
      t.references :site, null: false, foreign_key: true
      t.references :building, foreign_key: true
      t.references :floor, foreign_key: true
      t.references :unit, foreign_key: true
      t.string :ownership, null: false, default: "owner"
      t.boolean :is_primary, null: false, default: false
      t.boolean :lives_here, null: false, default: true
      t.boolean :is_approved, null: false, default: false
      t.date :move_in_date
      t.date :move_out_date
      t.timestamps
    end

    add_index :user_sites, [ :user_id, :unit_id ], unique: true
    add_index :user_sites, [ :site_id, :is_primary ]
    add_index :user_sites, :is_primary

    # Existing scalar location columns become first-class query paths. They stay
    # nullable so historical records created before the hierarchy still load.
    add_index :users, :current_site_id unless index_exists?(:users, :current_site_id)
    add_index :users, :unit_id unless index_exists?(:users, :unit_id)
    add_index :users, :building_id unless index_exists?(:users, :building_id)
    add_index :users, :floor_id unless index_exists?(:users, :floor_id)
    add_index :staffs, :site_id unless index_exists?(:staffs, :site_id)
    add_index :staffs, :unit_id unless index_exists?(:staffs, :unit_id)
    add_index :visitors, :site_id unless index_exists?(:visitors, :site_id)
    add_index :visitors, :building_id unless index_exists?(:visitors, :building_id)
    add_index :visitors, :floor_id unless index_exists?(:visitors, :floor_id)
    add_index :visitors, :unit_id unless index_exists?(:visitors, :unit_id)
  end
end
