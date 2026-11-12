class MaintenanceOrderFinishForm < BaseForm
  PERMITTED_ATTRIBUTES = %i[finished_at release_test_type next_preventive_km performed_service].freeze

  attribute :finished_at, Types::ZonedDateTimeType.new
  attribute :release_test_type, :string
  attribute :next_preventive_km, :integer
  attribute :performed_service, :string

  enum :release_test_type, MaintenanceOrder::RELEASE_TESTS

  before_validation :normalize_fields

  validates :finished_at, :release_test_type, :performed_service, presence: true
  validates :release_test_type, inclusion: { in: MaintenanceOrder::RELEASE_TESTS.map(&:to_s) }, allow_blank: true
  validates :next_preventive_km, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :order_must_be_pending
  validate :finished_at_must_not_precede_opening
  validate :next_preventive_must_be_ahead

  attr_accessor :maintenance_order

  class << self
    def enum_i18n_key
      MaintenanceOrder.model_name.i18n_key
    end

    def for_maintenance_order(maintenance_order)
      new(maintenance_order:, finished_at: Time.current.change(sec: 0), performed_service: maintenance_order.performed_service)
    end
  end

  def persisted?
    true
  end

  def submit
    maintenance_order.finished_at = finished_at
    maintenance_order.release_test_type = release_test_type
    maintenance_order.next_preventive_km = next_preventive_km
    maintenance_order.performed_service = performed_service
    maintenance_order.finish!
  end

  private

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
end
