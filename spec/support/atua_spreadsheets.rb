require 'spreadsheet'

module AtuaSpreadsheets
  DATE_FORMAT = Spreadsheet::Format.new(number_format: 'DD/MM/YYYY hh:mm:ss')

  class << self
    def cache
      @cache ||= {}
    end
  end

  def atua_fixture_path(name)
    file_fixture("atua/#{name}.xls")
  end

  def read_atua_fixture(name)
    AtuaSpreadsheets.cache[name] ||= Atua::ReadSpreadsheetCommand.call(Tenant.new, atua_fixture_path(name))
  end

  def atua_spreadsheet(headers:, rows:)
    Atua::ReadSpreadsheetCommand::Result.new(headers:, rows: rows.map { |row| headers.zip(row.values_at(*headers)).to_h })
  end

  def write_atua_spreadsheet(totals:, headers:, rows:)
    book = Spreadsheet::Workbook.new
    sheet = book.create_worksheet(name: 'Planilha 1')
    [totals, headers, *rows].each_with_index do |values, index|
      sheet.row(index).replace(values)
      values.each_with_index { |value, position| sheet.row(index).set_format(position, DATE_FORMAT) if value.is_a?(Date) }
    end

    path = Rails.root.join('tmp', "atua_spreadsheet_#{SecureRandom.hex(6)}.xls")
    book.write(path.to_s)
    path
  end
end

RSpec.configure do |config|
  config.include AtuaSpreadsheets
end
