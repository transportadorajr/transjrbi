class AddProfileFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    create_enum :user_type, %w[owner admin operator]

    change_table :users, bulk: true do |t|
      t.string :name
      t.string :phone
      t.enum :user_type, enum_type: :user_type, null: false, default: 'operator'
      t.datetime :activated_at
    end

    up_only do
      execute <<~SQL.squish
        UPDATE users SET name = split_part(email, '@', 1), activated_at = created_at
      SQL

      execute <<~SQL.squish
        UPDATE users SET user_type = 'owner'
        WHERE id IN (SELECT DISTINCT ON (tenant_id) id FROM users ORDER BY tenant_id, id)
      SQL
    end

    change_column_null :users, :name, false

    add_index :users, :tenant_id, unique: true, where: "user_type = 'owner'", name: 'index_users_on_tenant_id_where_owner_user_type'
  end
end
