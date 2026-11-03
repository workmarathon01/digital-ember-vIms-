json.message "Visitor registered successfully."
json.visitor do
  json.partial! "public/visitors/visitor", visitor: @visitor, include_qr_token: true, include_pass_url: true
end
