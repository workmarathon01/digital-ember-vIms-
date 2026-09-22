json.data do
  json.array! @staffs, partial: "staffs/staff", as: :staff
end

json.meta do
  json.partial! "shared/pagination", pagy: @pagy
end
