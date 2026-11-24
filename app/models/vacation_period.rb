class VacationPeriod
  ENTITLED_DAYS = 30
  MAX_SOLD_DAYS = 10
  MAX_PARTS = 3
  MIN_MAIN_PART_DAYS = 14
  MIN_PART_DAYS = 5
  DUE_SOON_DAYS = 60

  attr_reader :employee, :start_on, :vacations

  class << self
    def for_employee(employee, vacations: employee.vacations.to_a, until_on: Date.current)
      start_dates(employee, until_on).map do |start_on|
        new(employee:, start_on:, vacations: vacations.select { |vacation| vacation.acquisition_start_on == start_on })
      end
    end

    def start_dates(employee, until_on)
      return [] if employee.admitted_on.nil?

      (0..).lazy.map { |years| employee.admitted_on.advance(years:) }.take_while { |start_on| start_on <= until_on }.to_a
    end

    def find(employee, start_on, vacations: employee.vacations.to_a)
      return if employee.admitted_on.nil? || start_on.nil?

      new(employee:, start_on:, vacations: vacations.select { |vacation| vacation.acquisition_start_on == start_on })
    end
  end

  def initialize(employee:, start_on:, vacations: [])
    @employee = employee
    @start_on = start_on
    @vacations = vacations
  end

  def end_on
    years_after_start(1) - 1
  end

  def deadline_on
    years_after_start(2) - 1
  end

  def enjoyed_days
    vacations.sum(&:days_count)
  end

  def sold_days
    vacations.sum(&:sold_days)
  end

  def balance
    ENTITLED_DAYS - enjoyed_days - sold_days
  end

  def acquired?(on = Date.current)
    end_on < on
  end

  def status(today = Date.current)
    if !acquired?(today) then :acquiring
    elsif balance <= 0 then :taken
    elsif deadline_on < today then :overdue
    elsif deadline_on <= today + DUE_SOON_DAYS then :due_soon
    else :open
    end
  end

  private

  def years_after_start(count)
    employee.admitted_on.advance(years: start_on.year - employee.admitted_on.year + count)
  end
end
