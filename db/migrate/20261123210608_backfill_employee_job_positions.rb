class BackfillEmployeeJobPositions < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      INSERT INTO job_positions (tenant_id, name, activated_at, created_at, updated_at)
      SELECT DISTINCT tenant_id, UPPER(TRIM(role)), NOW(), NOW(), NOW()
      FROM employees
      WHERE NULLIF(TRIM(role), '') IS NOT NULL
      ON CONFLICT (tenant_id, name) DO NOTHING
    SQL

    execute <<~SQL.squish
      UPDATE employees e
      SET job_position_id = jp.id
      FROM job_positions jp
      WHERE jp.tenant_id = e.tenant_id
        AND jp.name = UPPER(TRIM(e.role))
        AND e.job_position_id IS NULL
    SQL
  end

  def down; end
end
