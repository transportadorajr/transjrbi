class BackfillExecutedRouteDistances < ActiveRecord::Migration[8.1]
  EXECUTED_DISTANCES = {
    '424' => 858, '75142' => 1343, '75143' => 1371, '75147' => 1031, '75148' => 1031, '75149' => 1031, '75150' => 1031,
    '75127' => 1391, '75122' => 1448
  }.freeze
  ROUTE = 'tenant_id, customer_code, origin_city, origin_state, destination_city, destination_state'.freeze
  UNIQUE_ROUTE = 'tenant_id, customer_code, origin_state, origin_city, destination_state, destination_city'.freeze

  def up
    execute <<~SQL.squish
      INSERT INTO route_distances (#{ROUTE}, distance_km, created_at, updated_at)
      SELECT DISTINCT ON (#{ROUTE}) #{ROUTE}, distance_km, NOW(), NOW()
      FROM (
        SELECT d.tenant_id, d.taker_code AS customer_code,
               UPPER(BTRIM(d.origin_city)) AS origin_city, UPPER(BTRIM(d.origin_state)) AS origin_state,
               UPPER(BTRIM(d.destination_city)) AS destination_city, UPPER(BTRIM(d.destination_state)) AS destination_state,
               executed.distance_km
        FROM (VALUES #{executed_values}) AS executed (number, distance_km)
        JOIN atua_transport_documents d ON d.number::text = executed.number
        WHERE d.document_kind = 'cte' AND d.canceled_at IS NULL AND d.taker_code IS NOT NULL
          AND NULLIF(BTRIM(d.origin_city), '') IS NOT NULL AND NULLIF(BTRIM(d.origin_state), '') IS NOT NULL
          AND NULLIF(BTRIM(d.destination_city), '') IS NOT NULL AND NULLIF(BTRIM(d.destination_state), '') IS NOT NULL
      ) candidates
      ORDER BY #{ROUTE}, distance_km DESC
      ON CONFLICT (#{UNIQUE_ROUTE})
      DO UPDATE SET distance_km = EXCLUDED.distance_km, updated_at = EXCLUDED.updated_at
    SQL

    Tenant.find_each { |tenant| RouteDistances::ApplyCommand.call(tenant) }
  end

  def down; end

  private

  def executed_values
    EXECUTED_DISTANCES.map { |number, distance_km| "(#{connection.quote(number)}, #{distance_km}::numeric)" }.join(', ')
  end
end
