module TablesHelper
  def html_table_to_rows(table: first('table'))
    table.all('tr').map { |row| row.all('th,td').map { |cell| cell.text.squish } }
  end

  def dl_to_hash(selector = 'dl')
    within(selector) { all('dt,dd').map { |node| node.text.squish }.each_slice(2).to_h }
  end
end

RSpec.configure do |config|
  config.include TablesHelper, type: :feature
end
