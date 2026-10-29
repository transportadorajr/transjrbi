class ExcludeCeIssuersFromFreightBilling < ActiveRecord::Migration[8.1]
  ISSUER_CODES = [6190, 1951].freeze

  def up
    execute <<~SQL.squish
      INSERT INTO excluded_issuers (tenant_id, code, name, created_at, updated_at)
      SELECT tenant_id, issuer_code, MAX(issuer_name), NOW(), NOW()
      FROM atua_transport_documents
      WHERE issuer_code IN (#{ISSUER_CODES.join(', ')}) AND issuer_name IS NOT NULL
      GROUP BY tenant_id, issuer_code
      ON CONFLICT (tenant_id, code) DO NOTHING
    SQL
  end

  def down
    execute "DELETE FROM excluded_issuers WHERE code IN (#{ISSUER_CODES.join(', ')})"
  end
end
