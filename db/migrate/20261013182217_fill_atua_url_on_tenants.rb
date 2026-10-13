class FillAtuaUrlOnTenants < ActiveRecord::Migration[8.1]
  ATUA_URL = 'https://transjr.atua.com.br/adm'.freeze

  def up
    execute <<~SQL.squish
      UPDATE tenants SET atua_url = #{connection.quote(ATUA_URL)} WHERE atua_url IS NULL
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE tenants SET atua_url = NULL WHERE atua_url = #{connection.quote(ATUA_URL)}
    SQL
  end
end
