json.registered @registered
json.currently_checked_in @currently_checked_in

if @visitor
  json.visitor do
    json.partial! "public/visitors/visitor", visitor: @visitor, hide_profile_image: true
  end
else
  json.visitor nil
end
