json.data do
  json.array! @banners, partial: "banners/banner", as: :banner
end

json.meta do
  json.partial! "shared/pagination", pagy: @pagy
end
