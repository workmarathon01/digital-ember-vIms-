json.extract! unit, :id, :site_id, :building_id, :floor_id, :name, :unit_type,
              :carpet_area, :status, :description, :created_at, :updated_at

json.site_name unit.site&.name
json.building_name unit.building&.name
json.floor_name unit.floor&.name
json.residents_count unit.user_sites.size
json.occupied unit.occupied?
json.location_label unit.location_label
json.full_address unit.full_address
json.url unit_url(unit, format: :json)
