json.sites @sites do |site|
  json.extract! site, :id, :name, :code
  json.display_name site.display_name
end

json.departments @departments do |department|
  json.extract! department, :id, :name, :code
end

json.minimum_password_length 12
