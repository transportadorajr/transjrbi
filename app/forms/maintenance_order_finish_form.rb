class MaintenanceOrderFinishForm < BaseForm
  PERMITTED_ATTRIBUTES = [:finished_at, :release_test_type, :next_preventive_km, :performed_service, :supervisor_id,
                          :supervisor_signature, { mechanic_signatures: {} }].freeze

  attribute :finished_at, Types::ZonedDateTimeType.new
  attribute :release_test_type, :string
  attribute :next_preventive_km, :integer
  attribute :performed_service, :string
  attribute :supervisor_id, :integer
  attribute :supervisor_signature, :string
  attribute :mechanic_signatures, default: -> { {} }

  enum :release_test_type, MaintenanceOrder::RELEASE_TESTS

  before_validation :normalize_fields

  validates :finished_at, :release_test_type, :performed_service, presence: true
  validates :release_test_type, inclusion: { in: MaintenanceOrder::RELEASE_TESTS.map(&:to_s) }, allow_blank: true
  validates :next_preventive_km, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :order_must_be_pending
  validate :finished_at_must_not_precede_opening
  validate :next_preventive_must_be_ahead
  validate :supervisor_must_sign, if: :signatures_required?
  validate :mechanics_must_sign, if: :signatures_required?

  attr_accessor :maintenance_order, :finished_by, :ip_address, :user_agent

  class << self
    def enum_i18n_key
      MaintenanceOrder.model_name.i18n_key
    end

    def for_maintenance_order(maintenance_order)
      new(maintenance_order:, finished_at: Time.current.change(sec: 0), performed_service: maintenance_order.performed_service,
          supervisor_id: maintenance_order.supervisor_id)
    end
  end

  def persisted?
    true
  end

  def signatures_required?
    MaintenanceOrderSignature.enabled?(maintenance_order.tenant)
  end

  def supervisors
    employees = maintenance_order.tenant.workshop_employees.supervisor

    employees.active.or(employees.where(id: maintenance_order.supervisor_id)).order(:name)
  end

  def signing_mechanics
    @signing_mechanics ||= maintenance_order.signing_mechanics.to_a
  end

  def submit
    assign_closing_data

    transaction do
      maintenance_order.finish!
      MaintenanceOrders::DeductStockCommand.call(maintenance_order, created_by: finished_by)
      create_signatures if signatures_required?
    end
  end

  private

  def assign_closing_data
    maintenance_order.finished_at = finished_at
    maintenance_order.release_test_type = release_test_type
    maintenance_order.next_preventive_km = next_preventive_km
    maintenance_order.performed_service = performed_service
    maintenance_order.supervisor = supervisor if signatures_required?
  end

  def create_signatures
    digest = maintenance_order.content_digest
    signed_at = Time.current

    create_signature(supervisor, :supervisor, supervisor_strokes, digest:, signed_at:)
    signing_mechanics.each do |mechanic|
      create_signature(mechanic, :mechanic, mechanic_strokes(mechanic), digest:, signed_at:)
    end
  end

  def create_signature(employee, role, strokes, digest:, signed_at:)
    maintenance_order.signatures.create!(
      tenant: maintenance_order.tenant, workshop_employee: employee, signer_role_type: role, signer_name: employee.name, strokes:,
      signed_at:, content_digest: digest, signed_by: finished_by, ip_address:, user_agent: user_agent.to_s.truncate(255)
    )
  end

  def supervisor
    return @supervisor if defined?(@supervisor)

    @supervisor = supervisors.find_by(id: supervisor_id) if supervisor_id.present?
  end

  def supervisor_strokes
    @supervisor_strokes ||= MaintenanceOrderSignature.parse_strokes(supervisor_signature)
  end

  def mechanic_strokes(mechanic)
    MaintenanceOrderSignature.parse_strokes(mechanic_signatures.to_h.stringify_keys[mechanic.id.to_s])
  end

  def normalize_fields
    self.performed_service = performed_service.to_s.strip.presence
  end

  def order_must_be_pending
    return if maintenance_order.may_finish?

    errors.add(:base, :not_pending, status: maintenance_order.status_type_name.downcase)
  end

  def finished_at_must_not_precede_opening
    return if finished_at.blank? || finished_at >= maintenance_order.opened_at

    errors.add(:finished_at, :before_opening)
  end

  def next_preventive_must_be_ahead
    return if next_preventive_km.blank? || maintenance_order.odometer_km.blank?
    return if next_preventive_km > maintenance_order.odometer_km

    errors.add(:next_preventive_km, :behind_odometer)
  end

  def supervisor_must_sign
    return errors.add(:supervisor_id, :blank) if supervisor_id.blank?
    return errors.add(:supervisor_id, :inclusion) if supervisor.nil?

    errors.add(:supervisor_signature, :blank) unless MaintenanceOrderSignature.drawn?(supervisor_strokes)
  end

  def mechanics_must_sign
    return errors.add(:base, :no_mechanic) if signing_mechanics.empty?

    signing_mechanics.each do |mechanic|
      next if MaintenanceOrderSignature.drawn?(mechanic_strokes(mechanic))

      errors.add(:base, :mechanic_signature_missing, name: mechanic.name)
    end
  end
end
