class CreateRevenueProjectionMemory < ActiveRecord::Migration[8.1]
  def change
    create_enum :revenue_projection_day_type, %w[regular weekday_holiday saturday_holiday bridge_day optional_day month_end]
    create_enum :revenue_projection_factor_type, %w[weekday_holiday saturday_holiday bridge_day optional_day month_end weekday_bias]

    create_table :revenue_projection_daily_totals do |t|
      t.references :tenant, null: false, foreign_key: true, index: false
      t.date :date, null: false
      t.integer :wday, null: false
      t.enum :day_type, enum_type: :revenue_projection_day_type, null: false, default: 'regular'
      t.bigint :billed_cents, null: false, default: 0
      t.integer :documents_count, null: false, default: 0
      t.bigint :hourly_cents, array: true, null: false, default: []
      t.datetime :consolidated_at, null: false

      t.timestamps
    end

    add_index :revenue_projection_daily_totals, %i[tenant_id date], unique: true

    create_table :revenue_projection_day_forecasts do |t|
      t.references :tenant, null: false, foreign_key: true, index: false
      t.date :date, null: false
      t.integer :wday, null: false
      t.enum :day_type, enum_type: :revenue_projection_day_type, null: false, default: 'regular'
      t.bigint :typical_cents, null: false
      t.decimal :factor, precision: 6, scale: 4, null: false
      t.bigint :forecast_cents, null: false
      t.bigint :low_cents, null: false
      t.bigint :high_cents, null: false
      t.bigint :actual_cents
      t.decimal :error_ratio, precision: 8, scale: 4
      t.boolean :backfilled, null: false, default: false
      t.datetime :forecast_at, null: false

      t.timestamps
    end

    add_index :revenue_projection_day_forecasts, %i[tenant_id date], unique: true

    create_table :revenue_projection_factors do |t|
      t.references :tenant, null: false, foreign_key: true, index: false
      t.enum :factor_type, enum_type: :revenue_projection_factor_type, null: false
      t.integer :wday
      t.decimal :value, precision: 6, scale: 4, null: false
      t.integer :observations_count, null: false, default: 0
      t.boolean :learned, null: false, default: false
      t.datetime :learned_at, null: false

      t.timestamps
    end

    add_index :revenue_projection_factors, %i[tenant_id factor_type wday], unique: true, nulls_not_distinct: true
  end
end
