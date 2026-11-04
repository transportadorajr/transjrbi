class ConvertDistanceAdjustmentsToRouteDistances < ActiveRecord::Migration[8.1]
  CANDIDATES = <<~SQL.squish.freeze
    SELECT d.tenant_id, d.taker_code AS customer_code,
           UPPER(BTRIM(d.origin_city)) AS origin_city, UPPER(BTRIM(d.origin_state)) AS origin_state,
           UPPER(BTRIM(d.destination_city)) AS destination_city, UPPER(BTRIM(d.destination_state)) AS destination_state,
           a.distance_km, COUNT(*) AS documents, MAX(a.updated_at) AS updated_at
    FROM distance_adjustments a
    JOIN atua_transport_documents d ON d.tenant_id = a.tenant_id AND d.number::text = a.transport_document_number
    WHERE d.taker_code IS NOT NULL
      AND NULLIF(BTRIM(d.origin_city), '') IS NOT NULL AND NULLIF(BTRIM(d.origin_state), '') IS NOT NULL
      AND NULLIF(BTRIM(d.destination_city), '') IS NOT NULL AND NULLIF(BTRIM(d.destination_state), '') IS NOT NULL
    GROUP BY 1, 2, 3, 4, 5, 6, 7
  SQL
  ROUTE = 'tenant_id, customer_code, origin_city, origin_state, destination_city, destination_state'.freeze

  def up
    report_conflicts

    execute <<~SQL.squish
      INSERT INTO route_distances (#{ROUTE}, distance_km, created_at, updated_at)
      SELECT DISTINCT ON (#{ROUTE}) #{ROUTE}, distance_km, NOW(), NOW()
      FROM (#{CANDIDATES}) candidates
      ORDER BY #{ROUTE}, documents DESC, updated_at DESC
      ON CONFLICT DO NOTHING
    SQL
  end

  def down; end

  private

  def report_conflicts
    select_rows(<<~SQL.squish).each { |row| say("Trecho com KM divergente: #{row.join(' | ')}") }
      SELECT #{ROUTE}, STRING_AGG(distance_km::text, ', ' ORDER BY documents DESC, updated_at DESC)
      FROM (#{CANDIDATES}) candidates
      GROUP BY #{ROUTE}
      HAVING COUNT(*) > 1
    SQL
  end
end
