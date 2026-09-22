json.token_type "Bearer"
json.access_token @access_token
json.refresh_token @refresh_token
json.expires_in @expires_in

json.user do
  json.partial! "users/user", user: @user
end
