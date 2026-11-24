class CreateRiskAssessments < ActiveRecord::Migration[8.1]
  def change
    create_enum :risk_assessment_provider_type, %w[apisul opentech]
    create_enum :risk_assessment_status_type, %w[recommended not_recommended in_progress]

    create_table :risk_assessments do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true, index: false
      t.enum :provider_type, enum_type: :risk_assessment_provider_type, null: false
      t.enum :status_type, enum_type: :risk_assessment_status_type
      t.integer :score
      t.date :valid_until
      t.text :notes

      t.timestamps
    end

    add_index :risk_assessments, %i[employee_id provider_type], unique: true
    add_index :risk_assessments, %i[tenant_id valid_until]
  end
end
