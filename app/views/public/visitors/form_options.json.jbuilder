json.sites @sites do |site|
  json.extract! site, :id, :name, :code, :city
  json.display_name site.display_name
end

json.units @units do |unit|
  json.extract! unit, :id, :name, :site_id, :building_id, :floor_id, :unit_type
  json.site_name unit.site&.name
  json.building_name unit.building&.name
  json.floor_name unit.floor&.name
  json.location_label unit.location_label
end
