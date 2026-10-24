json.extract! feature, :id, :key, :name, :description, :category, :icon,
              :default_enabled, :active, :sort_order, :created_at, :updated_at

json.sites_count feature.site_features.size
json.url feature_url(feature, format: :json)
