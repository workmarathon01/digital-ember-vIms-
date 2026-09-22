json.extract! role, :id, :name, :key, :description, :active, :is_system,
              :power_level, :created_at, :updated_at

json.system role.system?
json.permissions role.permissions.map { |permission| { resource: permission.resource, action: permission.action } }

json.url role_url(role, format: :json)
