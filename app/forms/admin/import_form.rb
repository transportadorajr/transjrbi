module Admin
  class ImportForm < BaseForm
    attribute :tenant_id, :integer
    attribute :report_type, :string
    attribute :start_date, :date
    attribute :end_date, :date

    validates :tenant, presence: true
    validates :report_type, inclusion: { in: Atua::Report::TYPES.map(&:to_s) }
    validates :start_date, :end_date, presence: true, if: :movement?
    validate :period_within_today, if: :movement?

    def tenant
      return @tenant if @tenant&.id == tenant_id

      @tenant = Tenant.find_by(id: tenant_id)
    end

    def movement?
      Atua::Report::MOVEMENT_TYPES.map(&:to_s).include?(report_type)
    end

    def submit
      errors.add(:base, :already_enqueued) unless Atua::ImportReportJob.perform_later(tenant.id, report_type, *period, production_access: Atua.production_access?)
    end

    private

    def period
      movement? ? [start_date, end_date] : [nil, nil]
    end

    def period_within_today
      return unless start_date && end_date

      errors.add(:end_date, :before_start_date) if end_date < start_date
      errors.add(:end_date, :future) if end_date > Date.current
    end
  end
end
