class VacationForm < BaseForm
  attribute :employee_id, :integer
  attribute :start_on, :date
  attribute :end_on, :date
  attribute :sold_days, :integer, default: 0
  attribute :notes, :string

  before_validation :normalize_fields

  validates :employee, :start_on, :end_on, presence: true
  validates :sold_days, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: VacationPeriod::MAX_SOLD_DAYS }
  validate :employee_must_have_an_admission_date
  validate :end_on_must_follow_start_on
  validate :part_must_reach_the_minimum
  validate :dates_must_be_free
  validate :dates_must_not_fall_on_a_trip
  validate :period_must_be_acquired
  validate :days_must_fit_the_balance
  validate :sold_days_must_fit_the_period
  validate :parts_must_fit_the_limit
  validate :main_part_must_still_fit

  attr_accessor :tenant
  attr_writer :vacation

  delegate :id, :persisted?, to: :vacation

  class << self
    def for_vacation(vacation)
      form = new(tenant: vacation.tenant, employee_id: vacation.employee_id, start_on: vacation.start_on, end_on: vacation.end_on,
                 sold_days: vacation.sold_days, notes: vacation.notes)
      form.vacation = vacation
      form
    end
  end

  def vacation
    @vacation ||= tenant.vacations.new
  end

  def employee
    return if employee_id.blank?

    return @employee if @employee&.id == employee_id

    @employee = tenant.employees.find_by(id: employee_id)
  end

  def available_employees
    tenant.employees.activated.or(tenant.employees.where(id: employee_id)).order(:name)
  end

  def period
    return if employee.nil? || start_on.blank?

    key = [employee.id, start_on]
    return @period if @period_key == key

    @period_key = key
    @period = persisted_period || oldest_open_period
  end

  def days_count
    return 0 if start_on.blank? || end_on.blank? || end_on < start_on

    (end_on - start_on).to_i + 1
  end

  def submit
    vacation.update!(employee:, acquisition_start_on: period.start_on, start_on:, end_on:, sold_days:, notes:)
  end

  private

  def normalize_fields
    self.sold_days ||= 0
    self.notes = notes.to_s.squish.presence
  end

  def persisted_period
    return unless vacation.persisted? && vacation.employee_id == employee.id

    VacationPeriod.find(employee, vacation.acquisition_start_on, vacations: other_vacations.to_a)
  end

  def oldest_open_period
    periods = VacationPeriod.recent_for_employee(employee, vacations: other_vacations.to_a, until_on: start_on)

    periods.find { |candidate| candidate.balance.positive? } || periods.last
  end

  def other_vacations
    vacations = employee.vacations
    vacation.persisted? ? vacations.where.not(id: vacation.id) : vacations
  end

  def employee_must_have_an_admission_date
    return if employee.nil? || employee.admitted_on.present?

    errors.add(:employee_id, :without_admission)
  end

  def end_on_must_follow_start_on
    return if start_on.blank? || end_on.blank? || end_on >= start_on

    errors.add(:end_on, :before_start_on)
  end

  def part_must_reach_the_minimum
    return if errors.any? || days_count >= VacationPeriod::MIN_PART_DAYS

    errors.add(:end_on, :too_short, count: VacationPeriod::MIN_PART_DAYS)
  end

  def period_must_be_acquired
    return if errors.any?

    if period.nil?
      errors.add(:start_on, :before_admission)
    elsif !period.acquired?(start_on)
      errors.add(:start_on, :not_acquired, date: I18n.l(period.end_on + 1))
    end
  end

  def days_must_fit_the_balance
    return if errors.any? || days_count + sold_days <= period.balance

    errors.add(:end_on, :exceeds_balance, count: period.balance, period: period_label)
  end

  def sold_days_must_fit_the_period
    return if errors.any? || period.sold_days + sold_days <= VacationPeriod::MAX_SOLD_DAYS

    errors.add(:sold_days, :exceeds_period, count: VacationPeriod::MAX_SOLD_DAYS - period.sold_days)
  end

  def parts_must_fit_the_limit
    return if errors.any? || period.vacations.size < VacationPeriod::MAX_PARTS

    errors.add(:start_on, :too_many_parts, count: VacationPeriod::MAX_PARTS)
  end

  def main_part_must_still_fit
    return if errors.any? || main_part_taken?

    remaining = period.balance - days_count - sold_days
    return if remaining >= VacationPeriod::MIN_MAIN_PART_DAYS && period.vacations.size + 1 < VacationPeriod::MAX_PARTS

    errors.add(:end_on, :main_part_missing, count: VacationPeriod::MIN_MAIN_PART_DAYS)
  end

  def main_part_taken?
    ([days_count] + period.vacations.map(&:days_count)).any? { |count| count >= VacationPeriod::MIN_MAIN_PART_DAYS }
  end

  def dates_must_be_free
    return if errors.any?

    overlapping = other_vacations.overlapping(start_on..end_on).order(:start_on)
    if overlapping.any?
      errors.add(:start_on, :overlaps_vacation, dates: overlapping.map { |other| period_text(other.start_on, other.end_on) }.to_sentence)
      return
    end

    taken = employee.work_schedule_days.by_period(start_on..end_on).order(:date).pluck(:date)
    errors.add(:start_on, :taken, dates: format_dates(taken)) if taken.any?
  end

  def dates_must_not_fall_on_a_trip
    return if errors.any? || employee.driver_code.nil?

    trip_dates = WorkSchedules::TripDatesCommand.call(tenant, employee.driver_code, start_on..end_on)[employee.driver_code].to_a.sort
    errors.add(:start_on, :on_trip, dates: format_dates(trip_dates)) if trip_dates.any?
  end

  def period_label
    period_text(period.start_on, period.end_on)
  end

  def period_text(first, last)
    I18n.t('vacations.period', start: I18n.l(first), finish: I18n.l(last))
  end

  def format_dates(dates)
    dates.map { |date| I18n.l(date) }.to_sentence
  end
end
