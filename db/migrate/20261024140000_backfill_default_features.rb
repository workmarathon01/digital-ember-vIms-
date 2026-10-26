class BackfillDefaultFeatures < ActiveRecord::Migration[8.1]
  class MigrationSite < ActiveRecord::Base
    self.table_name = "sites"
  end

  class MigrationSiteFeature < ActiveRecord::Base
    self.table_name = "site_features"
  end

  def up
    templates = Feature::STANDARD_TEMPLATES

    templates.each do |attrs|
      next if Feature.exists?(key: attrs[:key])

      Feature.create!(attrs.merge(active: true))
    end

    default_feature_ids = Feature.where(
      key: templates.select { |template| template[:default_enabled] }.map { |template| template[:key] }
    ).pluck(:id)

    MigrationSite.find_each do |site|
      # Do not overwrite a site that has already been configured.
      next if MigrationSiteFeature.where(site_id: site.id).exists?

      default_feature_ids.each do |feature_id|
        MigrationSiteFeature.create!(
          site_id: site.id,
          feature_id: feature_id,
          enabled: true,
          enabled_at: Time.current
        )
      end
    end
  end

  def down
    # Keep the catalog and entitlements; removing them would break existing sites.
  end
end
