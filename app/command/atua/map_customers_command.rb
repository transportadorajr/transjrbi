module Atua
  class MapCustomersCommand < MapReportCommand
    REPORT = 'rel_cliente_detalhado'.freeze
    ZIP_CODE_DIGITS = 8
    COLUMNS = {
      'cd_pessoa' => %i[code integer],
      'nm_pessoa' => %i[name string],
      'nm_fantasia' => %i[trade_name string],
      'tipo_pessoa' => %i[person_kind string],
      'nr_ie' => %i[state_registration string],
      'nm_logradouro' => %i[street string],
      'ds_complemento' => %i[complement string],
      'nm_bairro' => %i[district string],
      'nr_cep' => [:zip_code, :string, { pad: ZIP_CODE_DIGITS }],
      'cd_cidade' => %i[city_code integer],
      'nm_cidade' => %i[city string],
      'cd_uf' => %i[state_code integer],
      'ds_sigla' => %i[state string],
      'nr_telefone' => %i[phone string],
      'ds_email' => [:emails, :list, { separator: ';' }],
      'nm_atividade' => %i[activity string],
      'forma_pagamento' => %i[payment_method string],
      'prazo_pagamento' => %i[payment_term string],
      'dt_cadastro' => %i[registered_on date],
      'dt_ultima_emissao_cliente_pagador' => %i[last_billed_on date],
      'id_situacao' => %i[status string],
    }.freeze
    DOCUMENT_COLUMNS = { 'nr_cpf_cnpj' => :document }.freeze
    SPECIAL_COLUMNS = %w[
      id_whatsapp id_exportador id_optante_simples dt_consulta_optante_simples dt_mes_atualizacao dt_ano_atualizacao
    ].freeze
    RAW_COLUMNS = %w[
      dt_base_prazo_pagamento pr_limite_adiantamento vl_nota_fiscal_maximo_ctrc vl_credito vl_saldo cd_usuario_alteracao
      nm_usuario_alteracao dt_alteracao vl_aviso id_obrigatoriedade_peso_chegada id_limite_quebra id_pgto_frete_motorista
      id_pgto_frete_empresa id_impressao_vl_frete id_documento_cobranca id_pedagio id_documento_cobranca_entrega
      id_obrigatorio_comprovante_entrega id_responsavel_digitalizacao_comprovante_entrega id_obrigatorio_ticket_balanca
      id_responsavel_digitalizacao_ticket_balanca pr_limite_quebra qt_limite_quebra vl_limite_quebra cd_pessoa_seguradora
      nm_pessoa_seguradora ds_observacao nr_contabilidade_debito nr_contabilidade_adiantamento_cliente
      nr_contabilidade_credito nr_contabilidade_adiantamento nr_contabilidade_adiantamento_fornecedor
    ].freeze
    REQUIRED_COLUMNS = %w[cd_pessoa nm_pessoa nr_cpf_cnpj].freeze

    private

    def map(rows)
      rows.map { |row| map_row(row) }
    end

    def map_row(row)
      attributes = map_columns(row)
      code = attributes[:code]

      attributes.merge(
        whatsapp_at: yes_no(row, 'id_whatsapp', key: code, attribute: :whatsapp_at),
        exporter_at: yes_no(row, 'id_exportador', key: code, attribute: :exporter_at),
        simples_optant_at: yes_no(row, 'id_optante_simples', key: code, attribute: :simples_optant_at, date: row['dt_consulta_optante_simples']),
        updated_month_on: convert(row, 'dt_mes_atualizacao', :month_date, year: row['dt_ano_atualizacao']),
        raw_data: row,
      )
    end
  end
end
