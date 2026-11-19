class MaintenanceOrderForm < BaseForm
  ORDER_ATTRIBUTES = %i[plate opened_at odometer_km hour_meter driver_code supervisor_id
                        equipment_type equipment_other maintenance_type priority_type vehicle_stopped
                        execution_place_type affected_system_type
                        reported_defect diagnosis performed_service].freeze
  PERMITTED_ATTRIBUTES = [*ORDER_ATTRIBUTES, { mechanic_ids: [] }].freeze
  ITEM_FORMS = { parts: MaintenanceOrderPartForm, services: MaintenanceOrderServiceForm }.freeze

  attribute :plate, :string
  attribute :opened_at, Types::ZonedDateTimeType.new
  attribute :odometer_km, :integer
  attribute :hour_meter, :decimal
  attribute :driver_code, :integer
  attribute :supervisor_id, :integer
  attribute :mechanic_ids, default: -> { [] }
  attribute :equipment_type, :string
  attribute :equipment_other, :string
  attribute :maintenance_type, :string
  attribute :priority_type, :string, default: 'medium'
  attribute :vehicle_stopped, :boolean, default: false
  attribute :execution_place_type, :string, default: 'internal_workshop'
  attribute :affected_system_type, :string
  attribute :reported_defect, :string
  attribute :diagnosis, :string
  attribute :performed_service, :string

  enum :equipment_type, MaintenanceOrder::EQUIPMENTS
  enum :maintenance_type, MaintenanceOrder::MAINTENANCES
  enum :priority_type, MaintenanceOrder::PRIORITIES
  enum :execution_place_type, MaintenanceOrder::EXECUTION_PLACES
  enum :affected_system_type, MaintenanceOrder::AFFECTED_SYSTEMS

  before_validation :normalize_fields

  validates :plate, :opened_at, :equipment_type, :maintenance_type, :priority_type, :execution_place_type,
            :affected_system_type, :reported_defect, presence: true
  validates :equipment_type, inclusion: { in: MaintenanceOrder::EQUIPMENTS.map(&:to_s) }, allow_blank: true
  validates :maintenance_type, inclusion: { in: MaintenanceOrder::MAINTENANCES.map(&:to_s) }, allow_blank: true
  validates :priority_type, inclusion: { in: MaintenanceOrder::PRIORITIES.map(&:to_s) }, allow_blank: true
  validates :execution_place_type, inclusion: { in: MaintenanceOrder::EXECUTION_PLACES.map(&:to_s) }, allow_blank: true
  validates :affected_system_type, inclusion: { in: MaintenanceOrder::AFFECTED_SYSTEMS.map(&:to_s) }, allow_blank: true
  validates :equipment_other, presence: true, if: :equipment_type_other?
  validates :odometer_km, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :hour_meter, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :plate_must_be_registered
  validate :driver_must_exist
  validate :supervisor_must_exist
  validate :mechanics_must_exist
  validate :items_must_be_valid, unless: :persisted?

  attr_accessor :tenant, :opened_by
  attr_writer :maintenance_order

  delegate :id, :persisted?, to: :maintenance_order

  class << self
    def for_maintenance_order(maintenance_order)
      form = new(tenant: maintenance_order.tenant, mechanic_ids: maintenance_order.mechanic_assignments.pluck(:workshop_employee_id),
                 **maintenance_order.slice(*ORDER_ATTRIBUTES).symbolize_keys)
      form.maintenance_order = maintenance_order
      form
    end
  end

  def maintenance_order
    @maintenance_order ||= tenant.maintenance_orders.new
  end

  def parts_attributes=(rows)
    @items_attributes = items_attributes.merge(parts: item_rows(rows))
  end

  def services_attributes=(rows)
    @items_attributes = items_attributes.merge(services: item_rows(rows))
  end

  def parts
    item_forms(:parts)
  end

  def services
    item_forms(:services)
  end

  def new_item_form(kind)
    ITEM_FORMS.fetch(kind).new(maintenance_order: draft_order)
  end

  def submit
    transaction do
      maintenance_order.number ||= MaintenanceOrder.next_number(tenant)
      maintenance_order.opened_by ||= opened_by
      maintenance_order.update!(attributes.except('mechanic_ids').merge('driver_name' => driver_name, 'equipment_other' => equipment_other_value))
      save_mechanics
      save_items
    end
  end

  private

  def items_attributes
    @items_attributes ||= {}
  end

  def item_rows(rows)
    rows = rows.to_h if rows.respond_to?(:permitted?)
    rows = rows.values if rows.is_a?(Hash)
    Array(rows).map { |row| row.to_h.symbolize_keys }.reject { |row| row.except(:source_type).values.all?(&:blank?) }
  end

  def item_forms(kind)
    @item_forms ||= {}
    @item_forms[kind] ||= items_attributes.fetch(kind, []).map { |row| ITEM_FORMS.fetch(kind).new(maintenance_order: draft_order, **row) }
  end

  def draft_order
    @draft_order ||= MaintenanceOrder.new(tenant:)
  end

  def items_must_be_valid
    ITEM_FORMS.each_key do |kind|
      item_forms(kind).each.with_index(1) do |item_form, position|
        next if item_form.valid?

        errors.add(:base, :invalid_item, item: I18n.t(kind, scope: 'maintenance_orders.form.item_names'), position:,
                                         messages: item_form.errors.full_messages.to_sentence)
      end
    end
  end

  def save_mechanics
    maintenance_order.mechanic_assignments.where.not(workshop_employee_id: mechanic_ids).delete_all
    (mechanic_ids - maintenance_order.mechanic_assignments.pluck(:workshop_employee_id)).each do |workshop_employee_id|
      maintenance_order.mechanic_assignments.create!(tenant:, workshop_employee_id:)
    end
  end

  def save_items
    ITEM_FORMS.each do |kind, form_class|
      items_attributes.fetch(kind, []).each { |row| form_class.new(maintenance_order:, **row).save }
    end
  end

  def normalize_fields
    self.plate = plate.to_s.upcase.delete('^A-Z0-9')
    self.equipment_other = equipment_other.to_s.squish.upcase.presence
    self.reported_defect = reported_defect.to_s.strip
    self.diagnosis = diagnosis.to_s.strip.presence
    self.performed_service = performed_service.to_s.strip.presence
    self.mechanic_ids = Array(mechanic_ids).compact_blank.map(&:to_i).uniq
  end

  def equipment_other_value
    equipment_other if equipment_type_other?
  end

  def driver
    return if driver_code.blank?
    return @driver if defined?(@driver)

    @driver = tenant.atua_vehicles.drivers.find_by(driver_code:)
  end

  def driver_name
    driver&.driver_name
  end

  def plate_must_be_registered
    return if plate.blank? || plate == maintenance_order.plate

    errors.add(:plate, :inclusion) unless tenant.atua_vehicles.active.exists?(plate:)
  end

  def driver_must_exist
    errors.add(:driver_code, :inclusion) if driver_code.present? && driver.nil?
  end

  def supervisor_must_exist
    return if supervisor_id.blank?

    errors.add(:supervisor_id, :inclusion) unless tenant.workshop_employees.supervisor.exists?(id: supervisor_id)
  end

  def mechanics_must_exist
    assigned_ids = maintenance_order.persisted? ? maintenance_order.mechanic_assignments.pluck(:workshop_employee_id) : []
    available_ids = tenant.workshop_employees.active.where(id: mechanic_ids).pluck(:id) + assigned_ids

    errors.add(:mechanic_ids, :inclusion) if (mechanic_ids - available_ids).any?
  end
end
