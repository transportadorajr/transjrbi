class CreateAccesses < ActiveRecord::Migration[8.1]
  def change
    create_table :accesses do |t|
      t.references :user, null: false, foreign_key: true
      t.references :resource, null: false, foreign_key: true
      t.references :tenant, null: false, foreign_key: true
      t.boolean :reads, null: false, default: false
      t.boolean :creates, null: false, default: false

      t.timestamps
    end

    add_index :accesses, %i[user_id resource_id], unique: true
  end
end
