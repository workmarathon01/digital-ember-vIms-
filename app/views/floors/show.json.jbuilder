json.partial! "floors/floor", floor: @floor

json.units do
  json.array! @units, partial: "units/unit", as: :unit
end

json.user_sites do
  json.array! @user_sites, partial: "user_sites/user_site", as: :user_site
end
