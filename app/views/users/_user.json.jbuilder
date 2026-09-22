json.extract! user, :id, :email, :firstname, :lastname, :mobile, :active, :user_type,
              :role_id, :company_id, :unit_id, :current_site_id, :user_courtesy,
              :user_phase, :birth_date, :anniversary, :spouse_birth_date, :email_1,
              :email_2, :landline_number, :intercom_number, :user_address,
              :resident_type, :membership_type, :lives_here, :allow_fitout,
              :no_of_adults, :no_of_childrens, :no_of_pets, :differently_abled,
              :department_id, :designation_id, :manager_id, :about_me, :position,
              :organization_id, :blood_group, :profession, :location, :sub_location,
              :start_date, :end_date, :date_of_joining, :sign_in_count,
              :current_sign_in_at, :last_sign_in_at, :last_login_at,
              :failed_attempts, :locked_at, :created_at, :updated_at

json.full_name user.full_name
json.role_key user.role_key
json.role_label user.role_label
json.locked_out user.locked_out?

json.url user_url(user, format: :json)
