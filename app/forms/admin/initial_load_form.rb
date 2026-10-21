module Admin
  class InitialLoadForm < BaseForm
    DEFAULT_START_DATE = Date.new(2025, 9, 1)
    DEFAULT_END_DATE = Date.new(2026, 9, 30)

    attribute :tenant_id, :integer
    attribute :start_date, :date
    attribute :end_date, :date

    validates :tenant, :start_date, :end_date, presence: true
    validate :start_date_not_in_future
    validate :end_date_not_in_future
    validate :end_date_not_before_start_date

    class << self
      def with_default_period(tenant_id: nil)
        new(tenant_id:, start_date: DEFAULT_START_DATE, end_date: DEFAULT_END_DATE)
      end
    end

    def tenant
      return @tenant if @tenant&.id == tenant_id

      @tenant = Tenant.find_by(id: tenant_id)
    end

    def submit
      Atua::InitialLoadJob.perform_later(tenant.id, start_date, end_date)
    end

    private

    def start_date_not_in_future
      errors.add(:start_date, :future) if start_date && start_date > Date.current
    end

    def end_date_not_in_future
      errors.add(:end_date, :future) if end_date && end_date > Date.current
    end

    def end_date_not_before_start_date
      errors.add(:end_date, :before_start_date) if start_date && end_date && end_date < start_date
    end
  end
end
