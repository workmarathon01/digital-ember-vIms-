json.found @found
json.already_checked_in @already_checked_in
json.next_action @next_action
json.visitor do
  json.partial! "public/visitors/visitor", visitor: @visitor
end
