class MakeDriversResourceWritable < ActiveRecord::Migration[8.1]
  SLUG = 'drivers'.freeze

  def up
    execute "UPDATE resources SET writable = TRUE, updated_at = NOW() WHERE slug = #{connection.quote(SLUG)}"
  end

  def down
    execute "UPDATE resources SET writable = FALSE, updated_at = NOW() WHERE slug = #{connection.quote(SLUG)}"
  end
end
