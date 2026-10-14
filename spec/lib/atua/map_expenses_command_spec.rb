require 'rails_helper'

RSpec.describe Atua::MapExpensesCommand do
  let(:tenant) { build(:tenant) }
  let(:spreadsheet) { read_atua_fixture(:expenses) }
  let(:expenses) { described_class.call(tenant, spreadsheet) }

  def expense(code)
    expenses.find { |attributes| attributes[:code] == code }
  end

  describe '.call' do
    it 'maps one record per cd_caixa' do
      expect(spreadsheet.rows.size).to eq(1218)
      expect(expenses.size).to eq(1217)
    end

    it 'maps every attribute of an expense' do
      expect(expense(590_252).except(:raw_data)).to eq(
        code: 590_252, posted_at: Time.zone.local(2026, 10, 1, 8, 0), posted_on: Date.new(2026, 10, 1),
        document_on: Date.new(2026, 9, 30), accounting_on: Date.new(2026, 9, 30), settled_on: Date.new(2026, 10, 6),
        movement_code: nil, movement_on: nil,
        payee_code: 1951, payee_name: 'PESSOA 05102', payee_document: '455.630.868/28', payee_document_digits: '45563086828',
        history_code: 434, history_name: 'ADMINISTRATIVO - SALARIOS, COMIS. E IRRF', cash_account_name: nil,
        branch_code: 2189, branch_name: 'EMPRESA 04', headquarters_name: 'EMPRESA 04',
        trip_expense_kind: 'Despesa Fora da Viagem', spending_kind: nil,
        document_model: 'Recibo', document_number: nil, document_series: '1', document_key: nil,
        description: 'TEXTO ANONIMIZADO', accounting_account: nil, accounting_classification: nil,
        amount_cents: 781_540, discount_cents: 0, total_cents: 781_540, net_amount_cents: 781_540,
        pis_credit_cents: 0, cofins_credit_cents: 0, withholdings_cents: 0, paid_cents: nil, icms_cents: nil,
        plate: nil, vehicle_model: nil, trip_number: nil, trip_departure_on: nil, trip_arrival_on: nil,
        trip_driver_code: nil, trip_driver_name: nil,
        transport_document_code: nil, transport_document_number: nil, transport_document_series: nil,
        apportionment_count: 1, installment_count: nil,
        icms_credit_cents: nil, icms_credit_percentage: nil, attachment_at: nil
      )
      expect(expense(590_252)[:raw_data]).to eq([spreadsheet.rows.first])
    end

    it 'merges the rows of a repeated cd_caixa adding only the ICMS credit' do
      rows = spreadsheet.rows.select { |row| row['cd_caixa'].to_i == 601_638 }

      expect(expense(601_638)).to include(
        amount_cents: 161_854, total_cents: 161_854,
        icms_credit_cents: 18_341, icms_credit_percentage: BigDecimal('12'),
        raw_data: rows
      )
      expect(rows.size).to eq(2)
    end

    it 'reads the posting time with fraction' do
      expect(expenses.pluck(:posted_at)).to include(Time.zone.local(2026, 10, 1, 9, 18, 4, 633_085))
    end

    it 'splits the transport document number and series' do
      expect(expense_with(:transport_document_code, 80_750)).to include(transport_document_number: 74_071, transport_document_series: 1)
    end

    it 'splits the trip driver code and name' do
      expect(expenses.find { |attributes| attributes[:trip_driver_code] })
        .to include(trip_driver_code: 802, trip_driver_name: 'PESSOA 04931', trip_number: '2500653')
    end

    context 'when a required column is missing' do
      let(:spreadsheet) do
        fixture = read_atua_fixture(:expenses)
        atua_spreadsheet(headers: fixture.headers - %w[cd_caixa vl_credito_icms], rows: fixture.rows.first(1))
      end

      it 'raises a layout error naming the missing and the received columns' do
        expect { expenses }.to raise_error(
          Atua::LayoutError,
          /\AO relatório rel_caixa_detalhado veio sem as colunas obrigatórias cd_caixa, vl_credito_icms\. Colunas recebidas: dt_lancamento, cd_pessoa_favorecido/,
        )
      end
    end
  end

  def expense_with(attribute, value)
    expenses.find { |attributes| attributes[attribute] == value }
  end
end
