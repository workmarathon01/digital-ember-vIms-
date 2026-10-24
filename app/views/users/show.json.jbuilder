json.partial! "users/user", user: @user, include_features: true

json.user_sites do
  json.array! @user_sites, partial: "user_sites/user_site", as: :user_site
end

json.audit_logs do
  json.array! @audit_logs, partial: "audit_logs/audit_log", as: :log
end
