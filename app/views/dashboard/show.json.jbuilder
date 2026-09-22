json.users_count @users_count
json.visitors_count @visitors_count
json.checked_in_visitors_count @checked_in_visitors_count
json.staffs_count @staffs_count
json.pending_staffs_count @pending_staffs_count
json.attendance_open @attendance_open

json.recent_activity @recent_activity do |log|
  json.partial! "audit_logs/audit_log", log: log
end
