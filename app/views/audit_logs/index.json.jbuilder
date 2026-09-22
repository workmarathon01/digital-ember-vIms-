json.data do
  json.array! @logs, partial: "audit_logs/audit_log", as: :log
end

json.meta do
  json.partial! "shared/pagination", pagy: @pagy
end
