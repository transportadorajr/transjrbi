class AddCompanyResource < ActiveRecord::Migration[8.1]
  SLUG = 'company'.freeze
  NAME = 'Dados da empresa'.freeze

  def up
    execute <<~SQL.squish
      INSERT INTO resources (name, slug, writable, created_at, updated_at)
      VALUES (#{connection.quote(NAME)}, #{connection.quote(SLUG)}, TRUE, NOW(), NOW())
      ON CONFLICT (slug) DO NOTHING
    SQL
  end

  def down
    execute <<~SQL.squish
      DELETE FROM resources r WHERE r.slug = #{connection.quote(SLUG)}
        AND NOT EXISTS (SELECT 1 FROM accesses a WHERE a.resource_id = r.id)
    SQL
  end
end
