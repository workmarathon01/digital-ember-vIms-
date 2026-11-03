json.data do
  json.array! @departments, partial: "departments/department", as: :department
end
