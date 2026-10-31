json.message "Your registration was submitted. An administrator will review it shortly."
json.employee do
  json.id @user.id
  json.full_name @user.full_name
  json.email @user.email
  json.registration_status @user.registration_status
  json.submitted_at @user.registration_submitted_at
end
