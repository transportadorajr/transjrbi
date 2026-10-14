module Admin
  class InitialLoadForm < BaseForm
    attribute :tenant_id, :integer
    attribute :start_date, :date

    validates :tenant, :start_date, presence: true
    validate :start_date_not_in_future

    def tenant
      return @tenant if @tenant&.id == tenant_id

      @tenant = Tenant.find_by(id: tenant_id)
    end

    def submit
      Atua::InitialLoadJob.perform_later(tenant.id, start_date)
    end

    private

    def start_date_not_in_future
      errors.add(:start_date, :future) if start_date && start_date > Date.current
    end
  end
end
