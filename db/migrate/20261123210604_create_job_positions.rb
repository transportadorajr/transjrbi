class CreateJobPositions < ActiveRecord::Migration[8.1]
  def change
    create_table :job_positions do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name, null: false
      t.datetime :activated_at, default: -> { 'CURRENT_TIMESTAMP' }

      t.timestamps
    end

    add_index :job_positions, %i[tenant_id name], unique: true
  end
end
