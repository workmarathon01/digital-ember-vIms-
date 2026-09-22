class Current < ActiveSupport::CurrentAttributes
  attribute :user, :request_ip, :user_agent
end
