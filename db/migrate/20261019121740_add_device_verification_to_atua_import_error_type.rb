class AddDeviceVerificationToAtuaImportErrorType < ActiveRecord::Migration[8.1]
  def up
    add_enum_value :atua_import_error_type, 'device_verification', after: 'authentication'
  end

  def down
    execute <<~SQL.squish
      UPDATE atua_imports SET error_type = 'authentication' WHERE error_type = 'device_verification'
    SQL

    remove_enum_value :atua_import_error_type, 'device_verification'
  end
end
