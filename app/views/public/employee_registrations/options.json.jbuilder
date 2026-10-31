json.sites @sites do |site|
  json.extract! site, :id, :name, :code
  json.display_name site.display_name
end

json.minimum_password_length 12
