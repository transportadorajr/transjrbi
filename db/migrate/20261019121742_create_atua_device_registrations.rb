class CreateAtuaDeviceRegistrations < ActiveRecord::Migration[8.1]
  def change
    create_enum :atua_device_registration_status_type, %w[code_sent confirmed failed]

    create_table :atua_device_registrations do |t|
      t.references :tenant, null: false, foreign_key: true
      t.enum :status_type, enum_type: :atua_device_registration_status_type, null: false, default: 'code_sent'
      t.string :masked_email
      t.text :session_state
      t.datetime :expires_at, null: false
      t.datetime :confirmed_at
      t.text :error_message

      t.timestamps
    end
  end
end
