WAIT_BETWEEN_REPORTS = ENV.fetch('WAIT_SECONDS', 60).to_i
DEFAULT_START_DATE = Date.new(2025, 9, 1)
DEFAULT_END_DATE = Date.new(2026, 9, 30)

def find_tenant(value)
  return Atua.enabled_tenants.sole if value.blank?
  return Tenant.find(value) if value.match?(/\A\d+\z/)

  Tenant.where(Tenant.arel_table[:trade_name].matches(value)).sole
end

def month_periods(start_date, end_date)
  periods = []
  cursor = start_date

  while cursor <= end_date
    period_end = [cursor.end_of_month, end_date].min
    periods << [cursor, period_end]
    cursor = period_end + 1
  end

  periods
end

def already_imported?(tenant, report_type, start_date, end_date, source_type)
  tenant.atua_imports.succeeded.exists?(report_type:, start_date:, end_date:, source_type:)
end

def import_summary(import)
  counts = "#{import.rows_read} lidas · #{import.inserted_count} inseridas · #{import.updated_count} atualizadas"
  duration = import.finished_at && import.started_at ? "#{(import.finished_at - import.started_at).round}s" : '-'

  "#{import.status_type} (#{counts}, #{duration})"
end

tenant = find_tenant(ENV.fetch('TENANT', ''))
start_date = ENV['START_DATE'].present? ? Date.parse(ENV['START_DATE']) : DEFAULT_START_DATE
end_date = ENV['END_DATE'].present? ? Date.parse(ENV['END_DATE']) : DEFAULT_END_DATE
production_access = Atua.production_access?
client = Atua::Client.new(Atua::Configuration.for(tenant, production_access:))

steps = Atua::Report::REGISTRY_TYPES.map { |report_type| [report_type, nil, nil] }
month_periods(start_date, end_date).each do |month_start, month_end|
  Atua::Report::MOVEMENT_TYPES.each { |report_type| steps << [report_type, month_start, month_end] }
end

puts "Empresa: #{tenant.trade_name} (##{tenant.id})"
puts "Período: #{start_date.strftime('%d/%m/%Y')} a #{end_date.strftime('%d/%m/%Y')}"
puts "Atua: #{client.source_type} · #{steps.size} buscas · #{WAIT_BETWEEN_REPORTS}s entre cada busca"
puts

totals = Hash.new { |hash, key| hash[key] = Hash.new(0) }
fetched = false

steps.each_with_index do |(report_type, period_start, period_end), index|
  period = period_start ? "#{period_start} a #{period_end}" : 'cadastro completo'
  label = format('[%<index>02d/%<total>02d] %<report>-20s %<period>s', index: index + 1, total: steps.size, report: report_type, period:)

  if period_start && already_imported?(tenant, report_type, period_start, period_end, client.source_type)
    puts "#{label} já importado, pulando"
    totals[report_type][:skipped] += 1
    next
  end

  if fetched
    puts "Aguardando #{WAIT_BETWEEN_REPORTS}s..."
    sleep WAIT_BETWEEN_REPORTS
  end

  imports = Atua::ImportReportCommand.call(tenant, report_type, start_date: period_start, end_date: period_end, client:, raise_errors: true,
                                                                production_access:)
  fetched = true

  imports.each do |import|
    puts "#{label} #{import_summary(import)}"
    next if import.succeeded?

    abort "\nParado: #{report_type} #{period_start} a #{period_end} falhou (importação ##{import.id}, #{import.error_type}): " \
          "#{import.error_message}\nConfira o erro antes de rodar de novo; as buscas concluídas serão puladas."
  end

  totals[report_type][:imported] += 1
  totals[report_type][:rows] += imports.sum(&:rows_read)
rescue Atua::Error => e
  abort "\n#{label} parado: #{e.class.name.demodulize}: #{e.message}\n" \
        'Não repita a busca antes de entender o erro: a conta da Atua pode ser bloqueada. As buscas concluídas serão puladas na próxima execução.'
end

puts
puts 'Resumo:'
totals.each do |report_type, counts|
  puts "  #{report_type}: #{counts[:imported]} importadas (#{counts[:rows]} linhas), #{counts[:skipped]} puladas"
end
puts 'KM vazio, ligação das despesas e despesas do frete seguem na fila do GoodJob.'
