json.partial! "features/feature", feature: @feature

json.sites do
  json.array! @sites do |site|
    json.extract! site, :id, :name, :code
    json.display_name site.display_name
    json.url site_url(site, format: :json)
  end
end
