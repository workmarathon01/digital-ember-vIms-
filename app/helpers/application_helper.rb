module ApplicationHelper
  include Pagy::Frontend

  def navigation_entry(label, path, resource, action = :read)
    return unless current_user&.can?(resource, action)

    link_to label, path
  end

  def site_options(sites)
    sites.map { |site| [ site.display_name, site.id ] }
  end

  def building_options(buildings)
    buildings.map { |building| [ building.location_label, building.id ] }
  end

  def floor_options(floors)
    floors.map { |floor| [ floor.location_label, floor.id ] }
  end

  def unit_options(units)
    units.map { |unit| [ unit.location_label, unit.id ] }
  end
end
