class CreateDistanceAdjustments < ActiveRecord::Migration[8.1]
  def change
    create_table :distance_adjustments do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :transport_document_number, null: false
      t.decimal :distance_km, precision: 14, scale: 2, null: false
      t.datetime :applied_at

      t.timestamps
    end

    add_index :distance_adjustments, %i[tenant_id transport_document_number], unique: true
  end
end
