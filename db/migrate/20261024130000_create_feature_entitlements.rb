class CreateFeatureEntitlements < ActiveRecord::Migration[8.1]
  def change
    create_table :features do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description
      t.string :category, null: false, default: "general"
      t.string :icon
      t.boolean :default_enabled, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :sort_order, null: false, default: 0
      t.timestamps
    end

    add_index :features, :key, unique: true
    add_index :features, %i[active sort_order]
    add_index :features, :category

    create_table :site_features do |t|
      t.references :site, null: false, foreign_key: true
      t.references :feature, null: false, foreign_key: true
      t.boolean :enabled, null: false, default: true
      t.jsonb :settings, null: false, default: {}
      t.datetime :enabled_at
      t.references :enabled_by, null: true, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :site_features, %i[site_id feature_id], unique: true
    add_index :site_features, %i[site_id enabled]

    create_table :user_features do |t|
      t.references :user, null: false, foreign_key: true
      t.references :site, null: false, foreign_key: true
      t.references :feature, null: false, foreign_key: true
      t.boolean :enabled, null: false, default: true
      t.string :reason
      t.references :granted_by, null: true, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :user_features, %i[user_id site_id feature_id], unique: true,
              name: "index_user_features_on_user_site_feature"
    add_index :user_features, %i[site_id feature_id]
  end
end
