module GoodJobHelpers
  def use_good_job_adapter(*job_classes)
    adapter = GoodJob::Adapter.new(execution_mode: :external)

    job_classes.each { |job_class| allow(job_class).to receive(:queue_adapter).and_return(adapter) }
  end

  def good_job_record(job)
    GoodJob::Job.find_by!(active_job_id: job.job_id)
  end

  def mark_good_job_running(job)
    good_job_record(job).update!(performed_at: Time.current, scheduled_at: 1.day.from_now)
  end
end

RSpec.configure do |config|
  config.include GoodJobHelpers, type: :job
end
