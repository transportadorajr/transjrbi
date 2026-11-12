class MaintenanceOrderLaborForm < MaintenanceOrderItemForm
  PERMITTED_ATTRIBUTES = %i[workshop_employee_id worked_on start_time end_time hours activity].freeze
  TIME_FORMAT = /\A([01]\d|2[0-3]):[0-5]\d\z/

  attribute :workshop_employee_id, :integer
  attribute :worked_on, :date
  attribute :start_time, :string
  attribute :end_time, :string
  attribute :hours, :string
  attribute :activity, :string

  before_validation :normalize_fields

  validates :workshop_employee_id, :worked_on, presence: true
  validates :start_time, :end_time, format: { with: TIME_FORMAT }, allow_blank: true
  validate :workshop_employee_must_be_available
  validate :hours_must_be_informed

  class << self
    def attributes_of(labor)
      { workshop_employee_id: labor.workshop_employee_id, worked_on: labor.worked_on, start_time: labor.start_time&.strftime('%H:%M'),
        end_time: labor.end_time&.strftime('%H:%M'), hours: labor.hours && format_decimal(labor.hours), activity: labor.activity }
    end
  end

  def workshop_employees
    tenant.workshop_employees.where(active: true).or(tenant.workshop_employees.where(id: item.workshop_employee_id)).order(:name)
  end

  def hours_value
    return worked_hours if times_informed?

    self.class.parse_decimal(hours)
  end

  private

  def items
    maintenance_order.labors
  end

  def item_attributes
    { workshop_employee_id:, worked_on:, start_time: start_time.presence, end_time: end_time.presence, hours: hours_value, activity: }
  end

  def normalize_fields
    self.start_time = start_time.to_s.strip.first(5)
    self.end_time = end_time.to_s.strip.first(5)
    self.activity = activity.to_s.strip.presence
  end

  def times_informed?
    start_time.to_s.match?(TIME_FORMAT) && end_time.to_s.match?(TIME_FORMAT)
  end

  def minutes(time)
    hour, minute = time.split(':').map(&:to_i)
    (hour * 60) + minute
  end

  def worked_hours
    (BigDecimal(minutes(end_time) - minutes(start_time)) / 60).round(2)
  end

  def workshop_employee_must_be_available
    return if workshop_employee_id.blank? || workshop_employees.exists?(id: workshop_employee_id)

    errors.add(:workshop_employee_id, :inclusion)
  end

  def hours_must_be_informed
    if times_informed?
      errors.add(:end_time, :after_start) unless worked_hours.positive?
    elsif start_time.blank? && end_time.blank?
      errors.add(:hours, :blank_without_times) unless hours_value&.positive?
    elsif errors[:start_time].none? && errors[:end_time].none?
      errors.add(:base, :incomplete_times)
    end
  end
end
