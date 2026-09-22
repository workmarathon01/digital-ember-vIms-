json.partial! "users/user", user: @user

json.audit_logs do
  json.array! @audit_logs, partial: "audit_logs/audit_log", as: :log
end
