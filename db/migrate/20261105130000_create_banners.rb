class CreateBanners < ActiveRecord::Migration[8.1]
  def change
    create_table :banners do |t|
      t.references :site, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.jsonb :attachment_urls, null: false, default: []
      t.boolean :active, null: false, default: true
      t.integer :sort_order, null: false, default: 0
      t.timestamps
    end

    add_index :banners, [ :site_id, :active, :sort_order ]
  end
end
