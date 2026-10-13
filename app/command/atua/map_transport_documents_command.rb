module Atua
  class MapTransportDocumentsCommand < MapReportCommand
    REPORT = 'rel_ctrc_detalhado'.freeze
    DOCUMENT_KINDS = { 'CTRC' => 'cte', 'CE' => 'ce' }.freeze
    NOT_CHARGED = 'nao cobrado'.freeze
    COLUMNS = {
      'cd_ctrc' => %i[code integer],
      'nr_ctrc' => %i[number integer],
      'ds_serie' => %i[series integer],
      'id_tipo' => %i[issue_kind string],
      'ds_servico' => %i[service_kind string],
      'nr_cfop' => %i[cfop integer],
      'id_situacao_cte' => %i[cte_status string],
      'nr_chave' => %i[access_key string],
      'dt_emissao' => %i[issued_at datetime],
      'dt_lancamento' => %i[posted_on date],
      'dt_chegada' => %i[arrival_on date],
      'dt_vencimento_titulo' => %i[due_on date],
      'dt_cancelamento' => %i[canceled_at datetime],
      'ds_motivo_cancelamento' => %i[cancellation_reason string],
      'cd_pessoa_filial' => %i[branch_code integer],
      'nm_pessoa_filial' => %i[branch_name string],
      'cd_pessoa_matriz' => %i[headquarters_code integer],
      'nm_pessoa_matriz' => %i[headquarters_name string],
      'cd_agencia' => %i[agency_code integer],
      'nm_agencia' => %i[agency_name string],
      'nm_cidade_origem' => %i[origin_city string],
      'ds_uf_origem' => %i[origin_state string],
      'cd_cidade_origem' => %i[origin_city_code integer],
      'nm_cidade_destino' => %i[destination_city string],
      'ds_uf_destino' => %i[destination_state string],
      'cd_cidade_destino' => %i[destination_city_code integer],
      'cd_pessoa_embarque' => %i[sender_code integer],
      'nm_pessoa_remetente' => %i[sender_name string],
      'cd_pessoa_entrega' => %i[recipient_code integer],
      'nm_pessoa_destinatario' => %i[recipient_name string],
      'cd_pessoa_pagador' => %i[payer_code integer],
      'nm_pessoa_pagador' => %i[payer_name string],
      'cd_pessoa_tomador' => %i[taker_code integer],
      'nm_pessoa_tomador' => %i[taker_name string],
      'cd_pessoa_consignatario' => %i[consignee_code integer],
      'nm_pessoa_consignatario' => %i[consignee_name string],
      'cd_pessoa_motorista' => %i[driver_code integer],
      'nm_pessoa_motorista' => %i[driver_name string],
      'cd_veiculo' => %i[vehicle_code integer],
      'ds_placa' => %i[plate plate],
      'ds_placa_carreta' => %i[trailer_plate plate],
      'nr_eixo' => %i[axles integer],
      'id_proprietario_veiculo' => %i[vehicle_ownership string],
      'vl_peso' => %i[weight_tons decimal],
      'vl_peso_kg' => %i[weight_kg decimal],
      'qt_produto' => %i[product_quantity decimal],
      'nm_produto' => %i[product_name string],
      'ncm' => %i[ncm string],
      'vl_nota_fiscal' => %i[goods_value_cents cents],
      'nr_nota_fiscal' => %i[goods_invoice_numbers list],
      'nr_chave_nf' => %i[goods_invoice_keys list],
      'nr_ctrc_complementado' => %i[complemented_number integer],
      'nr_mdfe' => [:manifest_numbers, :list, { of: :integer }],
      'nr_ciot' => %i[ciot string],
      'nm_unidade_operacional' => %i[operational_unit string],
      'id_destino_mercadoria' => %i[cargo_destination string],
      'ds_percurso' => %i[route string],
      'nr_embarque' => %i[shipment_number string],
      'vl_frete_empresa' => %i[freight_cents cents],
      'vl_frete_peso' => %i[weight_freight_cents cents],
      'vl_frete_valor' => %i[value_freight_cents cents],
      'vl_advalorem' => %i[ad_valorem_cents cents],
      'vl_outros' => %i[other_charges_cents cents],
      'vl_pedagio_ctrc' => %i[toll_cents cents],
      'vl_base_icms_issqn' => %i[icms_base_cents cents],
      'vl_icms_issqn' => %i[icms_cents cents],
      'vl_icms_st' => %i[icms_st_cents cents],
      'vl_imposto_federal' => %i[federal_tax_cents cents],
      'vl_ibs' => %i[ibs_cents cents],
      'vl_cbs' => %i[cbs_cents cents],
      'vl_resultado' => %i[result_cents cents],
      'vl_frete_motorista' => %i[driver_freight_cents cents],
      'vl_adiantamento' => %i[advance_cents cents],
      'vl_comissao' => %i[commission_cents cents],
      'vl_seguro' => %i[insurance_cents cents],
      'vl_custo' => %i[cost_cents cents],
      'pr_margem_resultado' => %i[result_margin_percentage decimal],
      'vl_km_rodado' => %i[distance_km decimal],
    }.freeze
    DOCUMENT_COLUMNS = {
      'nr_cnpj_cpf_remetente' => :sender_document,
      'nr_cnpj_cpf_destinatario' => :recipient_document,
      'nr_cnpj_cpf_pagador' => :payer_document,
      'nr_cnpj_cpf_consignatario' => :consignee_document,
      'nr_cpf_motorista' => :driver_document,
    }.freeze
    SPECIAL_COLUMNS = %w[id_sintegra id_cobrado id_pendente_emissao_nfse].freeze
    RAW_COLUMNS = %w[
      nr_contrato nr_pedido nr_ordem_compra nr_liberacao_embarque dt_mes_emissao cd_pessoa_usuario nm_pessoa_usuario
      ds_endereco_remetente ds_uf_remetente nm_cidade_remetente ds_uf_consignatario nm_cidade_consignatario
      cd_pessoa_consignatario_embarque nm_pessoa_consignatario_embarque ds_endereco_destinatario ds_uf_destinatario
      nm_cidade_destinatario ds_uf_pagador nm_cidade_pagador nr_cnpj_cpf_proprietario_veiculo_doc
      cd_pessoa_proprietario_veiculo_doc nm_pessoa_proprietario_veiculo_doc id_enquadramento_proprietario_antt
      ds_endereco_proprietario_doc cd_pessoa_proprietario_veiculo_posse nm_pessoa_proprietario_veiculo_posse
      ds_endereco_proprietario_posse nm_marca ds_modelo vl_frete_pedagio_motorista vl_frete_ped_mot_saldo_adiantamento
      ds_modelo_nf pr_tolerancia_de_quebra ds_quebra_sobre vl_falta vl_peso_dif nm_grupo_produto
      nm_grupo_produto_transportado ds_motivo_diaria nr_pedido_pedagio nr_doc_anterior dt_emissao_doc_anterior
      pr_adiantamento_motorista vl_tarifa_empresa vl_tarifa_motorista pr_dif_frete vl_base_empresa vl_base_motorista
      vl_desconto_carta_frete vl_inss_retido vl_sest_senat vl_icms_diferenca nr_cst id_pedagio_ctrc vl_pedagio_empresa
      vl_pedagio_motorista vl_pedagio_pago_motorista id_pedagio_motorista vl_vale_combustivel vl_corretor nm_corretor
      vl_base vl_base_original vl_imposto_federal_debito vl_imposto_federal_credito vl_acrescimo_motorista
      vl_seguro_descontado id_seguradora nm_pessoa_seguradora vl_taxa_adm vl_inss_patronal cd_lote_carregamento
      ds_lote_carregamento nr_cartao_vale_pedagio nm_emissao_vale_pedagio id_enquadramento_federal nr_pgto_eletronico
      cd_pessoa_adm_pgto_eletronico nm_administradora nm_categoria ds_placa_embarque cd_pessoa_motorista_embarque
      nm_pessoa_embarque dt_saida_embarque cd_agencia_agenciador nm_agencia_agenciador cd_agencia_gerente
      nm_agencia_gerente cd_agencia_manifestador nm_agencia_manifestador cd_agencia_supervisor nm_agencia_supervisor
      cd_uf_origem cd_uf_destino ds_observacao id_operacao nr_ctrc_novo nr_ordem cd_agencia_ordem nm_agencia_ordem
      cd_usuario_ordem nm_usuario_ordem id_issqn_retido dt_embarque dt_chegada_destino nr_solicitacao nr_lacres
      pr_desconto_base_comissao_ctrc pr_desconto_mercadoria_base_comissao_ctrc ds_operacao_minuta nr_nfse perna
      nr_ctrc_primeira_perna
    ].freeze
    REQUIRED_COLUMNS = %w[
      cd_ctrc nr_ctrc ds_serie id_sintegra dt_emissao nm_pessoa_filial cd_pessoa_pagador vl_frete_empresa nr_mdfe id_cobrado
    ].freeze

    private

    def map(rows)
      rows.map { |row| map_row(row) }
    end

    def map_row(row)
      attributes = map_columns(row)
      code = attributes[:code]
      billing_number, charged = billing(row)

      attributes.merge(
        document_kind: document_kind(row),
        billing_number:,
        charged_at: charged ? previous.dig(code, :charged_at) || imported_at : nil,
        nfse_pending_at: yes_no(row, 'id_pendente_emissao_nfse', key: code, attribute: :nfse_pending_at),
        raw_data: row,
      )
    end

    def document_kind(row)
      kind = convert(row, 'id_sintegra', :string)
      DOCUMENT_KINDS.fetch(kind) do
        raise ConversionError, I18n.t('atua.errors.column_conversion', column: 'id_sintegra', report:,
                                                                       message: I18n.t('atua.errors.unknown_document_kind', value: kind.inspect))
      end
    end

    def billing(row)
      text = convert(row, 'id_cobrado', :string)
      return [nil, false] if text.nil? || I18n.transliterate(text).downcase == NOT_CHARGED

      [convert(row, 'id_cobrado', :integer), true]
    end
  end
end
