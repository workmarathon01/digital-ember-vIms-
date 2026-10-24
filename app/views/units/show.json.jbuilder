json.partial! "units/unit", unit: @unit

json.user_sites do
  json.array! @user_sites, partial: "user_sites/user_site", as: :user_site
end
