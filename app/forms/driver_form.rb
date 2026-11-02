class DriverForm < BaseForm
  DISPLAY_NAME_MAX_LENGTH = 40

  attribute :code, :integer
  attribute :display_name, :string

  before_validation :normalize_display_name

  validates :code, presence: true
  validates :display_name, length: { maximum: DISPLAY_NAME_MAX_LENGTH }

  attr_accessor :tenant

  class << self
    def for_driver(tenant, driver)
      new(tenant:, code: driver.driver_code, display_name: driver.display_name)
    end
  end

  def persisted?
    true
  end

  def to_param
    code.to_s
  end

  def submit
    tenant.drivers.find_or_initialize_by(code:).update!(display_name: display_name.presence)
  end

  private

  def normalize_display_name
    self.display_name = display_name.to_s.squish.upcase
  end
end
