json.extract! site, :id, :name, :code, :region, :address, :city, :state, :country,
              :postal_code, :timezone, :latitude, :longitude, :active, :description,
              :created_at, :updated_at

json.buildings_count site.buildings.size
json.floors_count site.floors.size
json.units_count site.units.size
json.residents_count site.user_sites.size
json.features_count site.site_features.size
json.display_name site.display_name
json.full_address site.full_address
json.url site_url(site, format: :json)
