json.extract! banner, :id, :site_id, :title, :description, :external_urls,
              :active, :sort_order, :created_at, :updated_at

json.site_name banner.site&.name
json.url banner_url(banner, format: :json)

json.attachments banner.attachments do |attachment|
  json.id attachment.id
  json.filename attachment.blob.filename.to_s
  json.content_type attachment.blob.content_type
  json.byte_size attachment.blob.byte_size
  json.image attachment.blob.image?
  json.url rails_blob_url(attachment, host: request.host_with_port, protocol: request.protocol)
end
