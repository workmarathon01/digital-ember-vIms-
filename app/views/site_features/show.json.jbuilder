json.site do
  json.partial! "sites/site", site: @site
end

json.features @features do |feature|
  json.partial! "features/feature", feature: feature
  json.enabled @enabled_feature_ids.include?(feature.id)
end

json.enabled_feature_ids @enabled_feature_ids
json.enabled_count @enabled_feature_ids.size
json.available_count @features.size
