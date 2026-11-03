class BackfillAtuaExpensesObservation < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE atua_expenses
      SET observation = NULLIF(BTRIM(raw_data -> 0 ->> 'ds_observacao_titulo'), ''), updated_at = NOW()
      WHERE NULLIF(BTRIM(raw_data -> 0 ->> 'ds_observacao_titulo'), '') IS DISTINCT FROM observation
    SQL
  end

  def down; end
end
