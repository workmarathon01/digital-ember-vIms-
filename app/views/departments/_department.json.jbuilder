json.extract! department, :id, :name, :code, :description, :active,
              :created_at, :updated_at
json.users_count department.users.size
