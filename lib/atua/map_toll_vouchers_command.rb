module Atua
  class MapTollVouchersCommand < MapReportCommand
    REPORT = 'rel_ctrc_vale_pedagio'.freeze
    COLUMNS = {
      'nr_ctrc' => %i[transport_document_number string],
      'id_sintegra' => %i[document_kind string],
      'nr_pedido' => %i[order_number string],
      'dt_emissao_pedido' => %i[ordered_on date],
      'dt_emissao' => %i[issued_on date],
      'dt_lancamento' => %i[posted_at datetime],
      'dt_cancelamento' => %i[canceled_on date],
      'ds_placa' => %i[plate plate],
      'cd_pessoa_filial' => %i[branch_code integer],
      'nm_pessoa_filial' => %i[branch_name string],
      'cd_pessoa_vale_pedagio' => %i[issuer_code integer],
      'nm_pessoa_vale_pedagio' => %i[issuer_name string],
      'nm_pessoa_motorista' => %i[driver_name string],
      'nm_pessoa_pagador' => %i[payer_name string],
      'qt_total_eixos_conjunto' => %i[axles integer],
      'vl_pedagio' => %i[toll_cents cents],
      'vl_pedagio_ctrc' => %i[charged_toll_cents cents],
      'vl_antecipado' => %i[advance_cents cents],
      'vl_taxa_adm' => %i[admin_fee_cents cents],
      'vl_total' => %i[total_cents cents],
    }.freeze
    DOCUMENT_COLUMNS = { 'nr_cnpj_pagador' => :payer_document }.freeze
    RAW_COLUMNS = %w[
      nr_carta_frete cd_agencia nm_agencia vl_frete_empresa vl_frete_motorista id_pedagio_empresa id_pedagio_motorista vl_por_eixo
      nr_cartao_vale_pedagio nr_pgto_eletronico ds_local_remoto nm_rota cd_pessoa_usuario nm_pessoa_usuario cd_pessoa_matriz nm_pessoa_matriz
      nm_proprietario_veiculo_doc id_propriedade_veiculo_doc nm_proprietario_veiculo_posse id_propriedade_veiculo_posse
    ].freeze
    REQUIRED_COLUMNS = %w[nr_ctrc nr_pedido dt_emissao cd_pessoa_filial vl_pedagio vl_pedagio_ctrc vl_total].freeze

    private

    def map(rows)
      rows.map do |row|
        attributes = map_columns(row)

        attributes.merge(code: [attributes[:branch_code], attributes[:transport_document_number], attributes[:order_number]].join(':'), raw_data: row)
      end
    end
  end
end
