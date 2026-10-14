module Atua
  class MapExpensesCommand < MapReportCommand
    REPORT = 'rel_caixa_detalhado'.freeze
    COLUMNS = {
      'cd_caixa' => %i[code integer],
      'dt_lancamento' => %i[posted_at datetime],
      'dt_lancamento_' => %i[posted_on date],
      'dt_documento' => %i[document_on date],
      'dt_contabil' => %i[accounting_on date],
      'dt_quitacao' => %i[settled_on date],
      'cd_movimento' => %i[movement_code integer],
      'dt_movimento' => %i[movement_on date],
      'cd_pessoa_favorecido' => %i[payee_code integer],
      'nm_pessoa_favorecido' => %i[payee_name string],
      'cd_historico' => %i[history_code integer],
      'nm_historico' => %i[history_name string],
      'nm_caixa_financeiro' => %i[cash_account_name string],
      'cd_pessoa_filial' => %i[branch_code integer],
      'nm_pessoa_filial' => %i[branch_name string],
      'nm_pessoa_matriz' => %i[headquarters_name string],
      'ds_despesa_viagem' => %i[trip_expense_kind string],
      'id_tipo_gasto' => %i[spending_kind string],
      'id_modelo' => %i[document_model string],
      'nr_documento' => %i[document_number string],
      'ds_serie' => %i[document_series string],
      'ds_chave_documento' => %i[document_key string],
      'ds_complemento' => %i[description string],
      'nr_contabilidade' => %i[accounting_account string],
      'nr_classificacao_contabilidade' => %i[accounting_classification string],
      'vl_lancamento' => %i[amount_cents cents],
      'vl_desconto' => %i[discount_cents cents],
      'vl_total' => %i[total_cents cents],
      'vl_lancamento_liquido' => %i[net_amount_cents cents],
      'vl_credito_pis' => %i[pis_credit_cents cents],
      'vl_credito_cofins' => %i[cofins_credit_cents cents],
      'vl_total_retencoes' => %i[withholdings_cents cents],
      'vl_pago_titulo' => %i[paid_cents cents],
      'vl_icms' => %i[icms_cents cents],
      'ds_placa' => %i[plate plate],
      'ds_modelo' => %i[vehicle_model string],
      'nr_viagem' => %i[trip_number string],
      'dt_saida' => %i[trip_departure_on date],
      'dt_chegada' => %i[trip_arrival_on date],
      'cd_ctrc' => %i[transport_document_code integer],
      'qt_rateio' => %i[apportionment_count integer],
      'qt_parcela' => %i[installment_count integer],
    }.freeze
    DOCUMENT_COLUMNS = { 'nr_cpf_cnpj_pessoa_favorecido' => :payee_document }.freeze
    SPECIAL_COLUMNS = %w[nr_ctrc nm_motorista_viagem arquivo_anexo pr_credito_icms vl_credito_icms].freeze
    RAW_COLUMNS = %w[
      ds_sigla_uf_favorecido nm_pais_favorecido cd_pessoa_usuario nm_pessoa_usuario nm_atividade_principal_favorecido
      nm_logradouro_favorecido nm_bairro_favorecido nr_endereco_favorecido ds_complemento_favorecido nr_cep_favorecido
      nm_cidade_favorecido dt_quitacao_titulo ds_tipo_pagamento id_estoque id_via_documento ds_via_documento
      proprietario_posse cd_veiculo_manutencao dt_conferencia nm_pessoa_conferencia nr_acumulador nr_cfop vl_base
      pr_aliquota vl_isento vl_outras vl_base_ibs_cbs vl_cbs vl_ibs_estadual vl_ibs_municipal vl_ibs COFINS CSLL IRPJ
      ISSQN ds_observacao_titulo
    ].freeze
    REQUIRED_COLUMNS = %w[cd_caixa dt_lancamento cd_historico nm_historico vl_lancamento vl_total vl_credito_icms].freeze

    private

    def map(rows)
      rows.group_by { |row| convert(row, 'cd_caixa', :integer) }.map do |code, expense_rows|
        map_expense(code, expense_rows)
      end
    end

    def map_expense(code, rows)
      row = rows.first
      transport_document_number, transport_document_series = convert(row, 'nr_ctrc', :number_series)
      trip_driver_code, trip_driver_name = convert(row, 'nm_motorista_viagem', :code_name)
      credits = rows.map { |credit_row| [convert(credit_row, 'vl_credito_icms', :cents), convert(credit_row, 'pr_credito_icms', :decimal)] }

      map_columns(row).merge(
        transport_document_number:,
        transport_document_series:,
        trip_driver_code:,
        trip_driver_name:,
        icms_credit_cents: credits.filter_map(&:first).presence&.sum,
        icms_credit_percentage: credits.max_by { |cents, _percentage| cents.to_i }.last,
        attachment_at: yes_no(row, 'arquivo_anexo', key: code, attribute: :attachment_at),
        raw_data: rows,
      )
    end
  end
end
