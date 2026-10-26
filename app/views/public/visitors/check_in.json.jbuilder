json.already_checked_in @already_checked_in
json.checked_in true
json.visitor do
  json.partial! "public/visitors/visitor", visitor: @visitor
end
