json.user do
  json.partial! "users/user", user: @user
end

if @site.present?
  json.site do
    json.partial! "sites/site", site: @site
  end
end

json.features @features do |feature|
  json.partial! "features/feature", feature: feature
  json.effective @effective_feature_ids.include?(feature.id)
  json.override @override_states.fetch(feature.id, "inherit")
end

json.effective_feature_ids @effective_feature_ids
json.effective_feature_keys @features.select { |feature| @effective_feature_ids.include?(feature.id) }.map(&:key)
