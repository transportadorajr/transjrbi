class JobPositionForm < BaseForm
  attribute :name, :string
  attribute :active, :boolean, default: true

  before_validation :normalize_fields

  validates :name, presence: true
  validate :name_must_be_available

  attr_accessor :tenant
  attr_writer :job_position

  delegate :id, :persisted?, to: :job_position

  class << self
    def for_job_position(job_position)
      form = new(name: job_position.name, active: job_position.activated?, tenant: job_position.tenant)
      form.job_position = job_position
      form
    end
  end

  def job_position
    @job_position ||= tenant.job_positions.new
  end

  def submit
    job_position.update!(name:, activated: active)
  end

  private

  def normalize_fields
    self.name = name.to_s.squish.upcase
  end

  def name_must_be_available
    return if name.blank?

    other_job_positions = persisted? ? tenant.job_positions.where.not(id: job_position.id) : tenant.job_positions
    errors.add(:name, :taken) if other_job_positions.exists?(name:)
  end
end
