json.extract! user_site, :id, :user_id, :site_id, :building_id, :floor_id, :unit_id,
              :ownership, :is_primary, :lives_here, :is_approved, :move_in_date,
              :move_out_date, :created_at, :updated_at

json.user_name user_site.user&.full_name
json.site_name user_site.site&.name
json.building_name user_site.building&.name
json.floor_name user_site.floor&.name
json.unit_name user_site.unit&.name
json.location_label user_site.location_label
json.primary user_site.is_primary?
json.url user_site_url(user_site, format: :json)
