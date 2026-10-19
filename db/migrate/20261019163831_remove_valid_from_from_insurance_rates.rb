class RemoveValidFromFromInsuranceRates < ActiveRecord::Migration[8.1]
  def up
    tenant_ids = select_values('SELECT tenant_id FROM insurance_rates GROUP BY tenant_id HAVING COUNT(*) > 1')

    execute <<~SQL.squish
      CREATE TEMPORARY TABLE kept_insurance_rates ON COMMIT DROP AS
      SELECT DISTINCT ON (tenant_id) tenant_id, id
      FROM insurance_rates
      ORDER BY tenant_id, (valid_from <= CURRENT_DATE) DESC,
               CASE WHEN valid_from <= CURRENT_DATE THEN valid_from END DESC NULLS LAST, valid_from
    SQL

    execute <<~SQL.squish
      UPDATE freight_expenses fe SET insurance_rate_id = kept.id
      FROM insurance_rates ir JOIN kept_insurance_rates kept ON kept.tenant_id = ir.tenant_id
      WHERE fe.insurance_rate_id = ir.id AND ir.id <> kept.id
    SQL

    execute 'DELETE FROM insurance_rates WHERE id NOT IN (SELECT id FROM kept_insurance_rates)'

    remove_index :insurance_rates, %i[tenant_id valid_from]
    remove_index :insurance_rates, :tenant_id
    remove_column :insurance_rates, :valid_from
    add_index :insurance_rates, :tenant_id, unique: true

    Tenant.where(id: tenant_ids).find_each { |tenant| FreightExpenses::CalculateInsuranceCommand.call(tenant) }
  end

  def down
    remove_index :insurance_rates, :tenant_id
    add_column :insurance_rates, :valid_from, :date
    execute 'UPDATE insurance_rates SET valid_from = created_at::date'
    change_column_null :insurance_rates, :valid_from, false
    add_index :insurance_rates, :tenant_id
    add_index :insurance_rates, %i[tenant_id valid_from], unique: true
  end
end
