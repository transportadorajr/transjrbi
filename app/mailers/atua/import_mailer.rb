module Atua
  class ImportMailer < ApplicationMailer
    def repeated_failures(import)
      @import = import
      @failure_streak = FailImportCommand::FAILURE_STREAK
      @imports_url = admin_imports_url(
        host: Rails.application.config.x.admin_host, tenant_id: import.tenant_id, report_type: import.report_type,
      )

      mail(
        to: Admin::User.order(:email).pluck(:email),
        subject: t('.subject', report: import.report_type_name, tenant: import.tenant.trade_name),
      )
    end
  end
end
