json.data do
  json.array! @sites, partial: "sites/site", as: :site
end

json.meta do
  json.partial! "shared/pagination", pagy: @pagy
end
