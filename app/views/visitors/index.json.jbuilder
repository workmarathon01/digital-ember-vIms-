json.visitors do
  json.array! @visitors, partial: "visitors/visitor", as: :visitor
end

json.meta do
  json.partial! "shared/pagination", pagy: @pagy
end
