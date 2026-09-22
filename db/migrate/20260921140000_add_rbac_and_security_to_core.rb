class AddRbacAndSecurityToCore < ActiveRecord::Migration[8.1]
  def up
    create_table :roles do |t|
      t.string :name, null: false
      t.string :key, null: false
      t.string :description
      t.boolean :active, default: true, null: false
      t.boolean :is_system, default: false, null: false
      t.integer :power_level, default: 0, null: false
      t.timestamps
    end
    add_index :roles, :key, unique: true

    create_table :permissions do |t|
      t.references :role, null: false, foreign_key: true
      t.string :resource, null: false
      t.string :action, null: false
      t.timestamps
    end
    add_index :permissions, [ :role_id, :resource, :action ], unique: true

    create_table :audit_logs do |t|
      t.references :actor, polymorphic: true, null: false
      t.string :action, null: false
      t.string :resource_type
      t.bigint :resource_id
      t.jsonb :details, default: {}
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end
    add_index :audit_logs, [ :resource_type, :resource_id ]
    add_index :audit_logs, :created_at

    create_table :staff_attendances do |t|
      t.references :staff, null: false, foreign_key: true
      t.datetime :punched_in_at, null: false
      t.datetime :punched_out_at
      t.string :ip_address
      t.timestamps
    end
    add_index :staff_attendances, [ :staff_id, :punched_in_at ]

    remove_column :users, :role
    add_reference :users, :role, foreign_key: true

    add_column :users, :failed_attempts, :integer, default: 0, null: false
    add_column :users, :locked_at, :datetime
    add_column :users, :lock_token, :string
    add_index :users, :lock_token, unique: true

    add_column :visitors, :pass_code, :string
    add_index :visitors, :pass_code, unique: true
    add_column :visitors, :otp_attempts, :integer, default: 0, null: false

    change_column :staffs, :working_schedule, :jsonb,
                  default: {}, using: "NULLIF(working_schedule, '')::jsonb"
  end

  def down
    remove_reference :users, :role
    remove_index :users, :lock_token if index_exists?(:users, :lock_token)
    remove_column :users, :lock_token
    remove_column :users, :locked_at
    remove_column :users, :failed_attempts
    remove_index :permissions, [ :role_id, :resource, :action ]
    drop_table :permissions
    drop_table :roles
    drop_table :audit_logs
    drop_table :staff_attendances
    remove_index :visitors, :pass_code if index_exists?(:visitors, :pass_code)
    remove_column :visitors, :pass_code
    remove_column :visitors, :otp_attempts
    change_column :staffs, :working_schedule, :text
    add_column :users, :role, :integer, null: false, default: 0
  end
end
