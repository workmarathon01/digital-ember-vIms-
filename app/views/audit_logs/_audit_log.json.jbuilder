json.extract! log, :id, :action, :actor_type, :actor_id, :resource_type,
              :resource_id, :ip_address, :user_agent, :details, :created_at, :updated_at

json.actor_name log.actor_name
