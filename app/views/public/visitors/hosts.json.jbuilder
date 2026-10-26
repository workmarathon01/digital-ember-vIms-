json.hosts @hosts do |host|
  json.id host.id
  json.full_name host.full_name
  json.role_label host.role_label
  json.position host.position
end
