json.data do
  json.array! @features, partial: "features/feature", as: :feature
end

json.meta do
  json.partial! "shared/pagination", pagy: @pagy
end
