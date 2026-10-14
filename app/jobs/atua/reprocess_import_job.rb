module Atua
  class ReprocessImportJob < ApplicationJob
    queue_with_priority 1
    include GoodJob::ActiveJobExtensions::Concurrency

    queue_as :atua

    self.good_job_labels = [-> { report_label }]

    good_job_concurrency_rule(label: -> { report_label }, perform_limit: 1)

    def perform(import_id)
      ReprocessImportCommand.call(Import.find(import_id))
    end

    private

    def report_label
      tenant_id, report_type = Import.where(id: arguments.first).pick(:tenant_id, :report_type)

      ImportReportJob.report_label(tenant_id, report_type)
    end
  end
end
