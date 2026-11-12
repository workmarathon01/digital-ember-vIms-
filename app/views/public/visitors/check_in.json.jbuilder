json.already_checked_in @already_checked_in
json.checked_in @visitor.checked_in?
json.checked_in_at @visitor.qr_checked_in_at

if @movement
  json.movement do
    json.direction @movement.direction
    json.occurred_at @movement.occurred_at
    json.source @movement.source
  end
end

json.visitor do
  json.partial! "public/visitors/visitor", visitor: @visitor
end
