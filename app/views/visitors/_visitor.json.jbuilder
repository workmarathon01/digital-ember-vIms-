json.extract! visitor, :id, :name, :contact_no, :purpose, :pass_code, :pass_number,
              :visit_type, :visitor_in_out, :status, :verified, :coming_from,
              :vehicle_number, :site_id, :building_id, :unit_id, :floor_id,
              :vhost_id, :visitor_staff_category_id, :parking_slot, :frequency,
              :working_days, :start_pass, :end_pass, :pass_start_date, :pass_end_date,
              :start_date, :end_date, :expected_date, :expected_time, :no_of_goods,
              :goods_inwards, :consignment_form, :driving_license, :skip_host_approval,
              :is_synced_with_hardware, :qr_generated_at, :qr_checked_in_at,
              :created_by_id, :created_at, :updated_at

json.checked_in visitor.checked_in?
json.pass_active visitor.pass_active?
json.created_by_name visitor.created_by&.full_name

json.url visitor_url(visitor, format: :json)
