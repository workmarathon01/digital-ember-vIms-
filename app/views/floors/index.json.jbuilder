json.data do
  json.array! @floors, partial: "floors/floor", as: :floor
end

json.meta do
  json.partial! "shared/pagination", pagy: @pagy
end
