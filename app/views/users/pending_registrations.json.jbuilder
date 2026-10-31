json.data do
  json.array! @pending_registrations, partial: "users/user", as: :user
end

json.meta do
  json.partial! "shared/pagination", pagy: @pagy
end
