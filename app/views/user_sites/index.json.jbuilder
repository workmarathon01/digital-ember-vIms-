json.data do
  json.array! @user_sites, partial: "user_sites/user_site", as: :user_site
end

json.meta do
  json.partial! "shared/pagination", pagy: @pagy
end
