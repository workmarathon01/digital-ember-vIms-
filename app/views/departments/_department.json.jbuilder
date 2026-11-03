json.extract! department, :id, :site_id, :name, :code, :description, :active,
              :created_at, :updated_at
json.site_name department.site&.name
json.users_count department.users.size
