class AssignCountryToForeignExportRecipients < ActiveRecord::Migration[8.1]
  FOREIGN_STATE = 'EX'.freeze
  COUNTRIES = {
    'FERROSIDER S/A' => 'argentina',
    'L ACERIE S A' => 'paraguay',
    'MONICA ALEJANDRA BENITEZ TORRES' => 'paraguay',
    'CJX SA' => 'paraguay',
    'FATA E.A.S. UNIPERSONAL' => 'paraguay',
    'SUNRISE INTERNACIONAL INC' => 'united_states',
    'ALL BRAZILIAN IMPORT EXPORT INC.' => 'united_states',
    'BRENNTAG SPA' => 'italy',
    'QORES SRL' => 'italy',
  }.freeze

  def up
    COUNTRIES.each do |name, country_type|
      execute <<~SQL.squish
        UPDATE atua_customers
        SET country_type = #{quote(country_type)}, country_edited_at = NOW(), updated_at = NOW()
        WHERE #{matching(name)} AND country_edited_at IS NULL
      SQL
    end
  end

  def down
    COUNTRIES.each do |name, country_type|
      execute <<~SQL.squish
        UPDATE atua_customers
        SET country_type = NULL, country_edited_at = NULL, updated_at = NOW()
        WHERE #{matching(name)} AND country_type = #{quote(country_type)}
      SQL
    end
  end

  private

  def matching(name)
    "state = #{quote(FOREIGN_STATE)} AND UPPER(REGEXP_REPLACE(TRIM(name), '\\s+', ' ', 'g')) = #{quote(name)}"
  end

  def quote(value)
    connection.quote(value)
  end
end
