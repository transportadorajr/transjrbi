class AddTollVouchersToAtuaImportReportType < ActiveRecord::Migration[8.1]
  def change
    add_enum_value :atua_import_report_type, 'toll_vouchers'
  end
end
