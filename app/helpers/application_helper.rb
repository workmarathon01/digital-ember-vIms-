module ApplicationHelper
  include Pagy::Frontend

  def navigation_entry(label, path, resource, action = :read)
    return unless current_user&.can?(resource, action)

    link_to label, path
  end
end
