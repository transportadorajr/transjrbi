class MoveMacroRegionCitiesToCities < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      INSERT INTO cities (tenant_id, macro_region_id, name, state, created_at, updated_at)
      SELECT DISTINCT ON (regions.tenant_id, regions.state, btrim(region_cities.name))
             regions.tenant_id, regions.id, btrim(region_cities.name), regions.state, NOW(), NOW()
      FROM macro_regions regions
      CROSS JOIN LATERAL unnest(regions.cities) WITH ORDINALITY AS region_cities(name, position)
      WHERE btrim(region_cities.name) <> ''
      ORDER BY regions.tenant_id, regions.state, btrim(region_cities.name), regions.id, region_cities.position
      ON CONFLICT (tenant_id, state, name) DO NOTHING
    SQL

    remove_column :macro_regions, :cities
  end

  def down
    add_column :macro_regions, :cities, :string, array: true, default: [], null: false

    execute <<~SQL.squish
      UPDATE macro_regions regions
      SET cities = (SELECT array_agg(cities.name ORDER BY cities.id) FROM cities WHERE cities.macro_region_id = regions.id)
      WHERE EXISTS (SELECT 1 FROM cities WHERE cities.macro_region_id = regions.id)
    SQL

    execute 'DELETE FROM cities'
  end
end
