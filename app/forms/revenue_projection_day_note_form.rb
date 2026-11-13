class RevenueProjectionDayNoteForm < BaseForm
  attribute :date, :date
  attribute :body, :string

  before_validation :normalize_fields

  validates :date, presence: true
  validates :body, length: { maximum: RevenueProjection::DayNote::BODY_MAX_LENGTH }
  validate :date_must_be_closed

  attr_accessor :tenant, :user

  class << self
    def for_date(tenant, date)
      new(tenant:, date:, body: tenant.revenue_projection_day_notes.find_by(date:)&.body)
    end
  end

  def persisted?
    true
  end

  def to_param
    date&.iso8601
  end

  def submit
    return note&.destroy! if body.blank?

    (note || tenant.revenue_projection_day_notes.new(date:)).update!(body:, user:)
  end

  private

  def note
    return @note if defined?(@note)

    @note = tenant.revenue_projection_day_notes.find_by(date:)
  end

  def normalize_fields
    self.body = body.to_s.strip
  end

  def date_must_be_closed
    errors.add(:date, :future) if date.present? && date >= Date.current
  end
end
