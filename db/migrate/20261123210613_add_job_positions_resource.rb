class AddJobPositionsResource < ActiveRecord::Migration[8.1]
  SLUG = 'job_positions'.freeze
  NAME = 'Cargos'.freeze
  EMPLOYEES_SLUG = 'employees'.freeze

  def up
    execute <<~SQL.squish
      INSERT INTO resources (name, slug, writable, created_at, updated_at)
      VALUES (#{connection.quote(NAME)}, #{connection.quote(SLUG)}, TRUE, NOW(), NOW())
      ON CONFLICT (slug) DO NOTHING
    SQL

    execute <<~SQL.squish
      INSERT INTO accesses (user_id, resource_id, tenant_id, reads, creates, created_at, updated_at)
      SELECT a.user_id, r.id, a.tenant_id, a.reads, a.creates, NOW(), NOW()
      FROM accesses a
      JOIN resources employees ON employees.id = a.resource_id AND employees.slug = #{connection.quote(EMPLOYEES_SLUG)}
      CROSS JOIN resources r
      WHERE r.slug = #{connection.quote(SLUG)}
      ON CONFLICT (user_id, resource_id) DO NOTHING
    SQL
  end

  def down
    execute <<~SQL.squish
      DELETE FROM accesses WHERE resource_id IN (SELECT id FROM resources WHERE slug = #{connection.quote(SLUG)})
    SQL
    execute "DELETE FROM resources WHERE slug = #{connection.quote(SLUG)}"
  end
end
