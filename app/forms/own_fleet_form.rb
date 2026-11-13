class OwnFleetForm < BaseForm
  PLATE_PATTERN = /\b[A-Z]{3}-?\d[A-Z0-9]\d{2}\b/

  attribute :plates, :string

  attr_accessor :tenant
  attr_writer :own_fleet

  delegate :id, :persisted?, to: :own_fleet

  class << self
    def for_tenant(tenant)
      own_fleet = OwnFleet.find_or_initialize_by(tenant:)

      form = new(plates: own_fleet.plates.join("\n"), tenant:)
      form.own_fleet = own_fleet
      form
    end
  end

  def own_fleet
    @own_fleet ||= OwnFleet.find_or_initialize_by(tenant:)
  end

  def plate_list
    plates.to_s.upcase.scan(PLATE_PATTERN).map { |plate| Atua::TransportDocument.normalize_plate(plate) }.uniq.sort
  end

  def submit
    own_fleet.update!(plates: plate_list)
  end
end
