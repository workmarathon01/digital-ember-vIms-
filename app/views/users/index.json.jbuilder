json.data do
  json.array! @users, partial: "users/user", as: :user
end

json.meta do
  json.partial! "shared/pagination", pagy: @pagy
end
