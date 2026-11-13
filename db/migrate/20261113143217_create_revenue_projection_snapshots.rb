class CreateRevenueProjectionSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_enum :revenue_projection_period_type, %w[month week]

    create_table :revenue_projection_snapshots do |t|
      t.references :tenant, null: false, foreign_key: true, index: false
      t.enum :period_type, enum_type: :revenue_projection_period_type, null: false
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.date :taken_on, null: false
      t.datetime :reference_at, null: false
      t.bigint :realized_cents, null: false, default: 0
      t.bigint :projected_cents, null: false, default: 0
      t.bigint :low_cents, null: false, default: 0
      t.bigint :high_cents, null: false, default: 0
      t.jsonb :days, null: false, default: []
      t.boolean :reconstructed, null: false, default: false

      t.timestamps
    end

    add_index :revenue_projection_snapshots, %i[tenant_id period_type period_start taken_on], unique: true
  end
end
