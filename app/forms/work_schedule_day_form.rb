class WorkScheduleDayForm < BaseForm
  MAX_PERIOD_DAYS = 31

  attribute :employee_id, :integer
  attribute :kind_type, :string, default: 'day_off'
  attribute :start_on, :date
  attribute :end_on, :date
  attribute :city_id, :integer
  attribute :leave_reason_type, :string
  attribute :notes, :string

  enum :kind_type, WorkScheduleDay::KINDS
  enum :leave_reason_type, WorkScheduleDay::LEAVE_REASONS

  before_validation :normalize_fields

  validates :employee, :start_on, presence: true
  validates :kind_type, inclusion: { in: WorkScheduleDay::KINDS.map(&:to_s) }
  validates :leave_reason_type, presence: true, if: :kind_type_leave?
  validates :leave_reason_type, inclusion: { in: WorkScheduleDay::LEAVE_REASONS.map(&:to_s) }, allow_blank: true
  validate :city_must_belong_to_the_tenant, if: :kind_type_day_off?
  validate :end_on_must_follow_start_on
  validate :period_must_fit_the_limit
  validate :dates_must_be_free
  validate :day_off_must_not_fall_on_a_trip

  attr_accessor :tenant

  class << self
    def for_employee(tenant, employee, start_on)
      new(tenant:, employee_id: employee.id, start_on:, end_on: start_on, city_id: WorkSchedules::SuggestCityCommand.call(employee)&.id)
    end
  end

  def employee
    return if employee_id.blank?

    tenant.employees.find_by(id: employee_id)
  end

  def city
    return if city_id.blank?

    tenant.cities.find_by(id: city_id)
  end

  def dates
    return [] if start_on.blank?

    (start_on..(end_on || start_on)).to_a
  end

  def available_cities
    cities = tenant.cities.activated

    cities.or(tenant.cities.where(id: city_id)).order(:state, :name)
  end

  def submit
    transaction do
      dates.each do |date|
        tenant.work_schedule_days.create!(employee:, date:, kind_type:, city: (city if kind_type_day_off?),
                                          leave_reason_type: (leave_reason_type if kind_type_leave?), notes:)
      end
    end
  end

  private

  def normalize_fields
    self.end_on ||= start_on
    self.notes = notes.to_s.squish.presence
    self.leave_reason_type = nil unless kind_type_leave?
  end

  def city_must_belong_to_the_tenant
    return if city

    errors.add(:city_id, city_id.blank? ? :blank : :invalid)
  end

  def end_on_must_follow_start_on
    return if start_on.blank? || end_on.blank? || end_on >= start_on

    errors.add(:end_on, :before_start_on)
  end

  def period_must_fit_the_limit
    return if start_on.blank? || end_on.blank? || end_on < start_on || dates.size <= MAX_PERIOD_DAYS

    errors.add(:end_on, :too_long, count: MAX_PERIOD_DAYS)
  end

  def dates_must_be_free
    return if employee.nil? || errors.any?

    taken = employee.work_schedule_days.by_period(dates).order(:date).pluck(:date)
    errors.add(:start_on, :taken, dates: format_dates(taken)) if taken.any?
  end

  def day_off_must_not_fall_on_a_trip
    return if employee.nil? || employee.driver_code.nil? || !kind_type_day_off? || errors.any?

    trip_dates = WorkSchedules::TripDatesCommand.call(tenant, employee.driver_code, start_on..end_on)[employee.driver_code].to_a.sort
    errors.add(:start_on, :on_trip, dates: format_dates(trip_dates)) if trip_dates.any?
  end

  def format_dates(dates)
    dates.map { |date| I18n.l(date) }.to_sentence
  end
end
