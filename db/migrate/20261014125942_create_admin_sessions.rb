class CreateAdminSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_sessions do |t|
      t.references :user, null: false, foreign_key: { to_table: :admin_users }
      t.string :token, null: false
      t.string :ip_address
      t.string :user_agent
      t.datetime :last_active_at, null: false

      t.timestamps
    end

    add_index :admin_sessions, :token, unique: true
  end
end
