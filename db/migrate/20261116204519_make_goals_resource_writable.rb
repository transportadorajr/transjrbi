class MakeGoalsResourceWritable < ActiveRecord::Migration[8.1]
  SLUG = 'goals'.freeze

  def up
    execute "UPDATE resources SET writable = TRUE, updated_at = NOW() WHERE slug = #{connection.quote(SLUG)}"
  end

  def down
    execute "UPDATE accesses SET creates = FALSE, updated_at = NOW() WHERE resource_id IN (SELECT id FROM resources WHERE slug = #{connection.quote(SLUG)})"
    execute "UPDATE resources SET writable = FALSE, updated_at = NOW() WHERE slug = #{connection.quote(SLUG)}"
  end
end
