class CreateCommissionRules < ActiveRecord::Migration[8.1]
  def change
    create_enum :commission_rule_destination_type, %w[national foreign]
    create_enum :commission_rule_base_type, %w[freight freight_without_icms]

    create_table :commission_rules do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :customer_group, null: false, foreign_key: true
      t.string :name, null: false
      t.enum :destination_type, enum_type: :commission_rule_destination_type, null: false
      t.enum :base_type, enum_type: :commission_rule_base_type, null: false
      t.decimal :percentage, precision: 7, scale: 4, null: false
      t.string :cities, array: true, null: false, default: []
      t.datetime :activated_at

      t.timestamps
    end
  end
end
