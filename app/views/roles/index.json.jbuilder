json.data do
  json.array! @roles, partial: "roles/role", as: :role
end

json.meta do
  json.total @roles.size
end
