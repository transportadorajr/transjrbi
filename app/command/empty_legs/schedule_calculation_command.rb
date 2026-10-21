module EmptyLegs
  class ScheduleCalculationCommand
    class << self
      def call(tenant_id, start_date = nil)
        new(tenant_id, start_date).call
      end
    end

    def initialize(tenant_id, start_date)
      @tenant_id = tenant_id
      @start_date = start_date
    end

    def call
      GoodJob::Job.transaction do
        GoodJob::Job.advisory_lock_key("#{concurrency_key}:schedule", function: 'pg_advisory_xact_lock') do
          dates = [start_date, *withdraw_waiting_jobs]
          CalculateJob.perform_later(tenant_id, dates.include?(nil) ? nil : dates.min)
        end
      end
    end

    private

    attr_reader :tenant_id, :start_date

    def concurrency_key
      CalculateJob.concurrency_key(tenant_id)
    end

    def withdraw_waiting_jobs
      withdrawn = waiting_jobs.select { |job| job.advisory_lock(function: 'pg_try_advisory_xact_lock') }.each(&:destroy)
      withdrawn.map { |job| job.serialized_params['arguments'].second }
    end

    def waiting_jobs
      GoodJob::Job.where(concurrency_key:, performed_at: nil, finished_at: nil).lock('FOR UPDATE SKIP LOCKED')
    end
  end
end
