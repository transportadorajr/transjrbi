class AddCommissionResources < ActiveRecord::Migration[8.1]
  RESOURCES = {
    'commission_rules' => ['Regras de comissão', true],
    'freight_expenses' => ['Despesas de frete', false],
  }.freeze

  def up
    RESOURCES.each do |slug, (name, writable)|
      execute <<~SQL.squish
        INSERT INTO resources (name, slug, writable, created_at, updated_at)
        VALUES (#{connection.quote(name)}, #{connection.quote(slug)}, #{connection.quote(writable)}, NOW(), NOW())
        ON CONFLICT (slug) DO NOTHING
      SQL
    end
  end

  def down
    execute <<~SQL.squish
      DELETE FROM resources r WHERE r.slug IN (#{RESOURCES.keys.map { |slug| connection.quote(slug) }.join(', ')})
        AND NOT EXISTS (SELECT 1 FROM accesses a WHERE a.resource_id = r.id)
    SQL
  end
end
