json.extract! visitor, :id, :name, :contact_no, :purpose, :pass_code, :pass_number,
              :visit_type, :visitor_in_out, :status, :verified, :coming_from,
              :vehicle_number, :site_id, :building_id, :floor_id, :unit_id,
              :expected_date, :expected_time, :start_pass, :end_pass,
              :pass_start_date, :pass_end_date, :frequency, :working_days,
              :no_of_goods, :goods_inwards, :created_at, :updated_at

json.checked_in visitor.checked_in?
json.pass_active visitor.pass_active?
json.checked_in_at visitor.qr_checked_in_at
json.site_name visitor.site&.name
json.building_name visitor.building&.name
json.floor_name visitor.floor&.name
json.unit_name visitor.unit&.name
json.location_label visitor.location_label
json.vhost_id visitor.vhost_id
json.host_name visitor.vhost&.full_name
unless local_assigns[:hide_profile_image]
  json.profile_image_url visitor.profile_image.attached? ? rails_blob_url(visitor.profile_image, host: request.host_with_port, protocol: request.protocol) : nil
end
json.qr_token visitor.qr_token if local_assigns[:include_qr_token]
