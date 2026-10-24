json.partial! "buildings/building", building: @building

json.floors do
  json.array! @floors, partial: "floors/floor", as: :floor
end

json.units do
  json.array! @units, partial: "units/unit", as: :unit
end

json.user_sites do
  json.array! @user_sites, partial: "user_sites/user_site", as: :user_site
end
