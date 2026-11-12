json.already_checked_out @already_checked_out
json.checked_in @visitor.checked_in?
json.checked_out_at @movement&.occurred_at if @movement&.outbound?

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
