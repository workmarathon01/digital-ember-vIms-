json.extract! building, :id, :site_id, :name, :code, :description, :created_at, :updated_at

json.site_name building.site&.name
json.floors_count building.floors.size
json.units_count building.units.size
json.residents_count building.user_sites.size
json.location_label building.location_label
json.url building_url(building, format: :json)
