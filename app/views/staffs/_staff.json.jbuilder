json.extract! staff, :id, :staff_id, :firstname, :lastname, :email, :mobile_no,
              :work_type, :status_type, :status, :staff_in_out, :site_id, :unit_id,
              :vendor_id, :valid_from, :valid_till, :joining_date, :date_of_birth,
              :longitude, :latitude, :working_schedule, :qr_generated_at,
              :created_by_id, :created_at, :updated_at

json.full_name staff.full_name
json.created_by_name staff.created_by&.full_name

json.url staff_url(staff, format: :json)
