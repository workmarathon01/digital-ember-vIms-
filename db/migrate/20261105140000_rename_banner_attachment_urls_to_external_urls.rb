class RenameBannerAttachmentUrlsToExternalUrls < ActiveRecord::Migration[8.1]
  def change
    rename_column :banners, :attachment_urls, :external_urls
  end
end
