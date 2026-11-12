json.partial! "visitors/visitor", visitor: @visitor

json.visits Array(@visitor_stays) do |stay|
  json.checked_in_at stay.checked_in_at
  json.checked_out_at stay.checked_out_at
  json.ongoing stay.ongoing?
  json.duration_seconds stay.duration_seconds
  json.source stay.entry_source
end

json.movements Array(@visitor_movements) do |movement|
  json.direction movement.direction
  json.occurred_at movement.occurred_at
  json.source movement.source
  json.ip_address movement.ip_address
  json.recorded_by_name movement.recorded_by&.full_name
end
