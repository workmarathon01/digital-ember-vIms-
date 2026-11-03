json.found @found
json.already_checked_in @already_checked_in
json.visitor do
  json.partial! "public/visitors/visitor", visitor: @visitor, include_pass_url: true
end
