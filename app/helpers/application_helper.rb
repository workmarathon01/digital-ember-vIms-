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
    buildings.map do |building|
      [ building.location_label, building.id, { data: { site_id: building.site_id } } ]
    end
  end

  def floor_options(floors)
    floors.map do |floor|
      [ floor.location_label, floor.id, { data: { site_id: floor.site_id, building_id: floor.building_id } } ]
    end
  end

  def unit_options(units)
    units.map do |unit|
      [ unit.location_label, unit.id, { data: { site_id: unit.site_id, building_id: unit.building_id, floor_id: unit.floor_id } } ]
    end
  end
end
