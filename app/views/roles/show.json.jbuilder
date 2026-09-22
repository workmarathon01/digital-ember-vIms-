json.partial! "roles/role", role: @role

json.members do
  json.array! @members, partial: "users/user", as: :user
end
