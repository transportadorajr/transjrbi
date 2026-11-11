class HolidayForm < BaseForm
  attribute :date, :date
  attribute :name, :string
  attribute :scope_type, :string, default: 'national'
  attribute :kind_type, :string, default: 'holiday'

  enum :scope_type, Holiday::SCOPES
  enum :kind_type, Holiday::KINDS

  before_validation :normalize_fields

  validates :date, :name, :scope_type, :kind_type, presence: true
  validates :scope_type, inclusion: { in: Holiday::SCOPES.map(&:to_s) }, allow_blank: true
  validates :kind_type, inclusion: { in: Holiday::KINDS.map(&:to_s) }, allow_blank: true
  validate :date_must_be_available

  attr_accessor :tenant
  attr_writer :holiday

  delegate :id, :persisted?, to: :holiday

  class << self
    def for_holiday(holiday)
      form = new(date: holiday.date, name: holiday.name, scope_type: holiday.scope_type, kind_type: holiday.kind_type,
                 tenant: holiday.tenant)
      form.holiday = holiday
      form
    end
  end

  def holiday
    @holiday ||= tenant.holidays.new
  end

  def submit
    holiday.update!(date:, name:, scope_type:, kind_type:)
  end

  private

  def normalize_fields
    self.name = name.to_s.squish
  end

  def date_must_be_available
    return if date.blank?

    other_holidays = persisted? ? tenant.holidays.where.not(id: holiday.id) : tenant.holidays
    errors.add(:date, :taken) if other_holidays.exists?(date:)
  end
end
