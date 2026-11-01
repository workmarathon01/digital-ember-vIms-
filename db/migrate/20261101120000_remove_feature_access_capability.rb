class RemoveFeatureAccessCapability < ActiveRecord::Migration[8.1]
  # Feature Access is now controlled by the super_admin role instead of a
  # user-grantable feature. Remove the leftover catalog entry and every site or
  # user entitlement that still points at it.
  def up
    feature_ids = select_values(
      "SELECT id FROM features WHERE key = 'feature_access'"
    )
    return if feature_ids.empty?

    ids = feature_ids.map(&:to_i).join(", ")
    execute "DELETE FROM user_features WHERE feature_id IN (#{ids})"
    execute "DELETE FROM site_features WHERE feature_id IN (#{ids})"
    execute "DELETE FROM features WHERE id IN (#{ids})"
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Feature Access is managed by the super_admin role."
  end
end
