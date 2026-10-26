json.extract! user, :id, :email, :firstname, :lastname, :mobile, :active, :user_type,
              :role_id, :company_id, :unit_id, :building_id, :floor_id, :current_site_id, :user_courtesy,
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
json.site_name user.current_site&.name
json.building_name user.building&.name
json.floor_name user.floor&.name
json.unit_name user.unit&.name
json.residence_label user.residence_label

if local_assigns[:include_features]
  # When the catalog is empty (for example before seeds run), the frontend
  # should not hide every feature-gated menu item. feature_keys is only
  # emitted when the user has a current site, so it remains nil otherwise.
  json.features_configured Feature.active.exists?
  if user.current_site.present?
    json.feature_keys user.feature_keys
    json.effective_features user.effective_features do |feature|
      json.extract! feature, :id, :key, :name, :category
    end
  end
end

json.url user_url(user, format: :json)
