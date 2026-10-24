json.data do
  json.array! @units, partial: "units/unit", as: :unit
end

json.meta do
  json.partial! "shared/pagination", pagy: @pagy
end
