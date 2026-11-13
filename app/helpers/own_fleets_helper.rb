module OwnFleetsHelper
  def own_fleet_plates(own_fleet)
    own_fleet.plates.any? ? own_fleet.plates.join(', ') : t('tax.blank')
  end

  def own_fleet_edit_button
    return unless can?(:update, :own_fleet)

    link_to edit_own_fleet_path, class: 'btn btn-outline-secondary btn-round' do
      concat icon(:pencil, class: 'me-2')
      concat t('own_fleets.show.edit')
    end
  end
end
