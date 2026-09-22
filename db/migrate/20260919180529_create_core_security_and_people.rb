class CreateCoreSecurityAndPeople < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false, default: ""
      t.string :password_digest, null: false
      t.string :encrypted_password, default: "", null: false
      t.string :firstname, null: false, default: ""
      t.string :lastname, null: false, default: ""
      t.integer :role, null: false, default: 0
      t.boolean :active, default: true, null: false
      t.datetime :last_login_at
      t.string :last_login_ip
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.integer :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string :current_sign_in_ip
      t.string :last_sign_in_ip
      t.string :provider
      t.string :uid
      t.string :user_type
      t.integer :company_id
      t.string :mobile
      t.integer :unit_id
      t.integer :current_site_id
      t.boolean :face_added
      t.string :user_face_url
      t.string :user_courtesy
      t.string :user_phase
      t.boolean :user_status
      t.integer :building_id
      t.integer :user_category_id
      t.text :user_address
      t.boolean :resident_type
      t.boolean :membership_type
      t.boolean :lives_here
      t.boolean :allow_fitout
      t.date :birth_date
      t.date :anniversary
      t.date :spouse_birth_date
      t.string :email_1
      t.string :email_2
      t.string :landline_number
      t.string :intercom_number
      t.integer :gst_number
      t.integer :pan_number
      t.string :ev_connection
      t.integer :no_of_adults
      t.integer :no_of_childrens
      t.integer :no_of_pets
      t.boolean :differently_abled
      t.integer :department_id
      t.integer :manager_id
      t.text :about_me
      t.string :position
      t.string :connection
      t.integer :organization_id
      t.string :profile_image_file_name
      t.string :profile_image_content_type
      t.bigint :profile_image_file_size
      t.datetime :profile_image_updated_at
      t.boolean :delete_request
      t.boolean :lad_long_required, default: true
      t.integer :vendor_id
      t.string :otp_digest
      t.datetime :otp_generated_at
      t.string :rotary_club
      t.datetime :wedding_date
      t.string :business_name
      t.string :business_category
      t.string :education_qualification
      t.string :office_address
      t.integer :rbm_by_id
      t.boolean :member_of_rmb
      t.string :facebook_link
      t.string :instagram_link
      t.string :linkedin_profile
      t.datetime :date_of_joining
      t.string :blood_group
      t.datetime :moving_date
      t.string :profession
      t.string :mgl_customer_number
      t.string :adani_electricity_account_no
      t.string :net_provider_name
      t.string :net_provider_id
      t.integer :floor_id
      t.boolean :is_admin_approved
      t.integer :created_by_id
      t.date :start_date
      t.date :end_date
      t.text :lotus_token
      t.string :sso_uid
      t.string :sso_provider
      t.string :microsoft_uid
      t.text :encrypted_microsoft_access_token
      t.string :encrypted_microsoft_access_token_iv
      t.text :encrypted_microsoft_refresh_token
      t.string :encrypted_microsoft_refresh_token_iv
      t.datetime :microsoft_token_expires_at
      t.boolean :lotus_hardware_synced, default: false
      t.datetime :last_birthday_wish_sent_at
      t.integer :designation_id
      t.string :location
      t.string :sub_location
      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :birth_date
    add_index :users, :microsoft_uid, unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, [ :sso_uid, :sso_provider ], unique: true
    add_index :users, :role
    add_index :users, :active

    create_table :visitors do |t|
      t.string :name
      t.string :contact_no
      t.text :purpose
      t.integer :site_id
      t.string :otp_digest
      t.boolean :status
      t.datetime :start_pass
      t.datetime :end_pass
      t.integer :created_by_id
      t.string :coming_from
      t.string :vehicle_number
      t.date :expected_date
      t.time :expected_time
      t.boolean :skip_host_approval, default: false, null: false
      t.boolean :goods_inwards, default: false, null: false
      t.string :visit_type
      t.string :frequency
      t.text :working_days
      t.string :pass_number
      t.bigint :visitor_staff_category_id
      t.integer :parking_slot
      t.string :visitor_in_out
      t.integer :vhost_id
      t.boolean :verified, default: false, null: false
      t.date :pass_start_date
      t.date :pass_end_date
      t.integer :building_id
      t.integer :unit_id
      t.integer :floor_id
      t.integer :parent_id
      t.boolean :driving_license
      t.boolean :consignment_form
      t.string :qr_token_digest
      t.datetime :qr_generated_at
      t.integer :qr_pending_expiry_minutes
      t.datetime :qr_checked_in_at
      t.boolean :is_deleted, default: false, null: false
      t.text :embedding
      t.text :lotus_token
      t.date :start_date
      t.date :end_date
      t.integer :no_of_goods
      t.boolean :is_synced_with_hardware
      t.datetime :otp_generated_at
      t.timestamps
    end

    add_index :visitors, :created_by_id
    add_index :visitors, :qr_generated_at
    add_index :visitors, :qr_token_digest
    add_index :visitors, :vhost_id
    add_index :visitors, :visitor_staff_category_id
    add_index :visitors, :contact_no
    add_index :visitors, :is_deleted

    create_table :staffs do |t|
      t.string :firstname
      t.string :lastname
      t.string :email
      t.string :mobile_no
      t.integer :unit_id
      t.string :work_type
      t.integer :vendor_id
      t.datetime :valid_from
      t.datetime :valid_till
      t.boolean :status
      t.text :working_schedule
      t.integer :site_id
      t.float :longitude
      t.float :latitude
      t.string :staff_id
      t.string :status_type, default: "Pending", null: false
      t.integer :created_by_id
      t.text :embedding
      t.date :date_of_birth
      t.string :staff_in_out
      t.date :joining_date
      t.string :qr_token_digest
      t.datetime :qr_generated_at
      t.timestamps
    end

    add_index :staffs, :staff_id, unique: true
    add_index :staffs, [ :mobile_no, :site_id ], unique: true
    add_index :staffs, :created_by_id
    add_index :staffs, :status_type
  end
end
