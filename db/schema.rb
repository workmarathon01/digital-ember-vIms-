# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_21_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "actor_id", null: false
    t.string "actor_type", null: false
    t.datetime "created_at", null: false
    t.jsonb "details", default: {}
    t.string "ip_address"
    t.bigint "resource_id"
    t.string "resource_type"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["actor_type", "actor_id"], name: "index_audit_logs_on_actor"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["resource_type", "resource_id"], name: "index_audit_logs_on_resource_type_and_resource_id"
  end

  create_table "permissions", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.string "resource", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["role_id", "resource", "action"], name: "index_permissions_on_role_id_and_resource_and_action", unique: true
    t.index ["role_id"], name: "index_permissions_on_role_id"
  end

  create_table "roles", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.boolean "is_system", default: false, null: false
    t.string "key", null: false
    t.string "name", null: false
    t.integer "power_level", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_roles_on_key", unique: true
  end

  create_table "staff_attendances", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "punched_in_at", null: false
    t.datetime "punched_out_at"
    t.bigint "staff_id", null: false
    t.datetime "updated_at", null: false
    t.index ["staff_id", "punched_in_at"], name: "index_staff_attendances_on_staff_id_and_punched_in_at"
    t.index ["staff_id"], name: "index_staff_attendances_on_staff_id"
  end

  create_table "staffs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "created_by_id"
    t.date "date_of_birth"
    t.string "email"
    t.text "embedding"
    t.string "firstname"
    t.date "joining_date"
    t.string "lastname"
    t.float "latitude"
    t.float "longitude"
    t.string "mobile_no"
    t.datetime "qr_generated_at"
    t.string "qr_token_digest"
    t.integer "site_id"
    t.string "staff_id"
    t.string "staff_in_out"
    t.boolean "status"
    t.string "status_type", default: "Pending", null: false
    t.integer "unit_id"
    t.datetime "updated_at", null: false
    t.datetime "valid_from"
    t.datetime "valid_till"
    t.integer "vendor_id"
    t.string "work_type"
    t.jsonb "working_schedule", default: {}
    t.index ["created_by_id"], name: "index_staffs_on_created_by_id"
    t.index ["mobile_no", "site_id"], name: "index_staffs_on_mobile_no_and_site_id", unique: true
    t.index ["staff_id"], name: "index_staffs_on_staff_id", unique: true
    t.index ["status_type"], name: "index_staffs_on_status_type"
  end

  create_table "users", force: :cascade do |t|
    t.text "about_me"
    t.boolean "active", default: true, null: false
    t.string "adani_electricity_account_no"
    t.boolean "allow_fitout"
    t.date "anniversary"
    t.date "birth_date"
    t.string "blood_group"
    t.integer "building_id"
    t.string "business_category"
    t.string "business_name"
    t.integer "company_id"
    t.string "connection"
    t.datetime "created_at", null: false
    t.integer "created_by_id"
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.integer "current_site_id"
    t.datetime "date_of_joining"
    t.boolean "delete_request"
    t.integer "department_id"
    t.integer "designation_id"
    t.boolean "differently_abled"
    t.string "education_qualification"
    t.string "email", default: "", null: false
    t.string "email_1"
    t.string "email_2"
    t.text "encrypted_microsoft_access_token"
    t.string "encrypted_microsoft_access_token_iv"
    t.text "encrypted_microsoft_refresh_token"
    t.string "encrypted_microsoft_refresh_token_iv"
    t.string "encrypted_password", default: "", null: false
    t.date "end_date"
    t.string "ev_connection"
    t.boolean "face_added"
    t.string "facebook_link"
    t.integer "failed_attempts", default: 0, null: false
    t.string "firstname", default: "", null: false
    t.integer "floor_id"
    t.integer "gst_number"
    t.string "instagram_link"
    t.string "intercom_number"
    t.boolean "is_admin_approved"
    t.boolean "lad_long_required", default: true
    t.string "landline_number"
    t.datetime "last_birthday_wish_sent_at"
    t.datetime "last_login_at"
    t.string "last_login_ip"
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.string "lastname", default: "", null: false
    t.string "linkedin_profile"
    t.boolean "lives_here"
    t.string "location"
    t.string "lock_token"
    t.datetime "locked_at"
    t.boolean "lotus_hardware_synced", default: false
    t.text "lotus_token"
    t.integer "manager_id"
    t.boolean "member_of_rmb"
    t.boolean "membership_type"
    t.string "mgl_customer_number"
    t.datetime "microsoft_token_expires_at"
    t.string "microsoft_uid"
    t.string "mobile"
    t.datetime "moving_date"
    t.string "net_provider_id"
    t.string "net_provider_name"
    t.integer "no_of_adults"
    t.integer "no_of_childrens"
    t.integer "no_of_pets"
    t.string "office_address"
    t.integer "organization_id"
    t.string "otp_digest"
    t.datetime "otp_generated_at"
    t.integer "pan_number"
    t.string "password_digest", null: false
    t.string "position"
    t.string "profession"
    t.string "profile_image_content_type"
    t.string "profile_image_file_name"
    t.bigint "profile_image_file_size"
    t.datetime "profile_image_updated_at"
    t.string "provider"
    t.integer "rbm_by_id"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.boolean "resident_type"
    t.bigint "role_id"
    t.string "rotary_club"
    t.integer "sign_in_count", default: 0, null: false
    t.date "spouse_birth_date"
    t.string "sso_provider"
    t.string "sso_uid"
    t.date "start_date"
    t.string "sub_location"
    t.string "uid"
    t.integer "unit_id"
    t.datetime "updated_at", null: false
    t.text "user_address"
    t.integer "user_category_id"
    t.string "user_courtesy"
    t.string "user_face_url"
    t.string "user_phase"
    t.boolean "user_status"
    t.string "user_type"
    t.integer "vendor_id"
    t.datetime "wedding_date"
    t.index ["active"], name: "index_users_on_active"
    t.index ["birth_date"], name: "index_users_on_birth_date"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["lock_token"], name: "index_users_on_lock_token", unique: true
    t.index ["microsoft_uid"], name: "index_users_on_microsoft_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role_id"], name: "index_users_on_role_id"
    t.index ["sso_uid", "sso_provider"], name: "index_users_on_sso_uid_and_sso_provider", unique: true
  end

  create_table "visitors", force: :cascade do |t|
    t.integer "building_id"
    t.string "coming_from"
    t.boolean "consignment_form"
    t.string "contact_no"
    t.datetime "created_at", null: false
    t.integer "created_by_id"
    t.boolean "driving_license"
    t.text "embedding"
    t.date "end_date"
    t.datetime "end_pass"
    t.date "expected_date"
    t.time "expected_time"
    t.integer "floor_id"
    t.string "frequency"
    t.boolean "goods_inwards", default: false, null: false
    t.boolean "is_deleted", default: false, null: false
    t.boolean "is_synced_with_hardware"
    t.text "lotus_token"
    t.string "name"
    t.integer "no_of_goods"
    t.integer "otp_attempts", default: 0, null: false
    t.string "otp_digest"
    t.datetime "otp_generated_at"
    t.integer "parent_id"
    t.integer "parking_slot"
    t.string "pass_code"
    t.date "pass_end_date"
    t.string "pass_number"
    t.date "pass_start_date"
    t.text "purpose"
    t.datetime "qr_checked_in_at"
    t.datetime "qr_generated_at"
    t.integer "qr_pending_expiry_minutes"
    t.string "qr_token_digest"
    t.integer "site_id"
    t.boolean "skip_host_approval", default: false, null: false
    t.date "start_date"
    t.datetime "start_pass"
    t.boolean "status"
    t.integer "unit_id"
    t.datetime "updated_at", null: false
    t.string "vehicle_number"
    t.boolean "verified", default: false, null: false
    t.integer "vhost_id"
    t.string "visit_type"
    t.string "visitor_in_out"
    t.bigint "visitor_staff_category_id"
    t.text "working_days"
    t.index ["contact_no"], name: "index_visitors_on_contact_no"
    t.index ["created_by_id"], name: "index_visitors_on_created_by_id"
    t.index ["is_deleted"], name: "index_visitors_on_is_deleted"
    t.index ["pass_code"], name: "index_visitors_on_pass_code", unique: true
    t.index ["qr_generated_at"], name: "index_visitors_on_qr_generated_at"
    t.index ["qr_token_digest"], name: "index_visitors_on_qr_token_digest"
    t.index ["vhost_id"], name: "index_visitors_on_vhost_id"
    t.index ["visitor_staff_category_id"], name: "index_visitors_on_visitor_staff_category_id"
  end

  add_foreign_key "permissions", "roles"
  add_foreign_key "staff_attendances", "staffs"
  add_foreign_key "users", "roles"
end
