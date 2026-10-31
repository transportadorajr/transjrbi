require 'rails_helper'

RSpec.describe Atua::MapTollVouchersCommand do
  let(:tenant) { create(:tenant) }
  let(:row) do
    {
      'nr_ctrc' => 74_855.0, 'id_sintegra' => 'CTRC', 'ds_placa' => 'BDZ-8J90', 'dt_emissao' => '24/10/26', 'dt_lancamento' => '24/10/26 10:00',
      'dt_cancelamento' => nil, 'cd_pessoa_filial' => 2.0, 'nm_pessoa_filial' => 'JR TRANSPORTES', 'vl_pedagio_ctrc' => 0.0, 'vl_pedagio' => 585.17,
      'qt_total_eixos_conjunto' => 6.0, 'vl_antecipado' => nil, 'vl_taxa_adm' => 0.0, 'vl_total' => 585.17, 'cd_pessoa_vale_pedagio' => 8055.0,
      'nm_pessoa_vale_pedagio' => 'TAG TESTE', 'nr_pedido' => 3.2000000000000004e+16, 'dt_emissao_pedido' => DateTime.new(2026, 10, 24, 15, 50),
      'nm_pessoa_motorista' => 'MOTORISTA TESTE', 'nm_pessoa_pagador' => 'CLIENTE TESTE LTDA', 'nr_cnpj_pagador' => '11.222.333/0001-81'
    }
  end

  def spreadsheet(rows, headers: rows.first.keys)
    Atua::ReadSpreadsheetCommand::Result.new(headers:, rows:)
  end

  it 'maps the toll paid apart from the toll charged on the transport document' do
    record = described_class.call(tenant, spreadsheet([row])).sole

    expect(record).to include(
      code: '2:74855:32000000000000004', transport_document_number: '74855', document_kind: 'CTRC', order_number: '32000000000000004',
      ordered_on: Date.new(2026, 10, 24), issued_on: Date.new(2026, 10, 24), plate: 'BDZ8J90', branch_code: 2, issuer_code: 8055,
      issuer_name: 'TAG TESTE', axles: 6, toll_cents: 58_517, charged_toll_cents: 0, total_cents: 58_517,
      payer_document_digits: '11222333000181', canceled_on: nil, raw_data: row
    )
  end

  it 'keeps two orders of the same transport document apart' do
    records = described_class.call(tenant, spreadsheet([row, row.merge('nr_pedido' => '10000000000000000001')]))

    expect(records.pluck(:code)).to eq(%w[2:74855:32000000000000004 2:74855:10000000000000000001])
  end

  it 'rejects a layout without the toll columns' do
    expect { described_class.call(tenant, spreadsheet([row.except('vl_pedagio')])) }.to raise_error(Atua::LayoutError, /vl_pedagio/)
  end
end
