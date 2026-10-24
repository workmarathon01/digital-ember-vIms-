json.data do
  json.array! @buildings, partial: "buildings/building", as: :building
end

json.meta do
  json.partial! "shared/pagination", pagy: @pagy
end
