json.extract! floor, :id, :site_id, :building_id, :name, :level, :description, :created_at, :updated_at

json.site_name floor.site&.name
json.building_name floor.building&.name
json.units_count floor.units.size
json.residents_count floor.user_sites.size
json.location_label floor.location_label
json.url floor_url(floor, format: :json)
