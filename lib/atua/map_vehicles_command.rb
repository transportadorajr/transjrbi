module Atua
  class MapVehiclesCommand < MapReportCommand
    REPORT = 'rel_veiculo_terceiro_detalhado'.freeze
    RENAVAM_DIGITS = 11
    COLUMNS = {
      'cd_veiculo' => %i[code integer],
      'ds_placa' => %i[plate plate],
      'id_categoria' => %i[category string],
      'id_tipo' => %i[vehicle_kind string],
      'cd_tipo_veiculo' => %i[vehicle_kind_code integer],
      'id_rodado' => %i[wheelset string],
      'id_carroceria' => %i[body string],
      'cd_marca' => %i[brand_code integer],
      'nm_marca' => %i[brand string],
      'ds_modelo' => %i[model string],
      'dt_ano_fabricacao' => %i[manufacture_year integer],
      'dt_ano_modelo' => %i[model_year integer],
      'nr_renavam' => [:renavam, :string, { pad: RENAVAM_DIGITS }],
      'nr_chassi' => %i[chassis string],
      'ds_cor' => %i[color string],
      'id_proprietario_veiculo' => %i[ownership string],
      'cd_pessoa_transportadora' => %i[owner_code integer],
      'nm_pessoa_transportadora' => %i[owner_name string],
      'nr_antt' => %i[antt string],
      'cd_motorista' => %i[driver_code integer],
      'nm_motorista' => %i[driver_name string],
      'nr_cnh' => %i[driver_license string],
      'id_risco' => %i[risk_status string],
      'dt_vcto_dados' => %i[data_expires_on date],
      'dt_atualizacao' => %i[source_updated_at datetime],
      'id_situacao' => %i[status string],
      'cd_cidade' => %i[city_code integer],
      'nm_cidade' => %i[city string],
      'cd_uf' => %i[state_code integer],
      'ds_sigla' => %i[state string],
    }.freeze
    DOCUMENT_COLUMNS = {
      'nr_cnpj_cpf' => :owner_document,
      'nr_cpf_motorista' => :driver_document,
    }.freeze
    SPECIAL_COLUMNS = %w[
      id_whatsapp_proprietario_doc id_whatsapp_motorista id_alto_desempenho dt_mes_cadastro dt_ano_cadastro
      dt_mes_atualizacao dt_ano_atualizacao
    ].freeze
    RAW_COLUMNS = %w[
      nm_pessoa id_atualizado dt_validade cd_veiculo_conjunto_cavalo ds_observacao nm_empresa_rastreador id_assoalho
      vl_comprimento vl_largura vl_altura nr_telefone_proprietario_doc nr_telefone_motorista
    ].freeze
    REQUIRED_COLUMNS = %w[cd_veiculo ds_placa].freeze

    private

    def map(rows)
      rows.map { |row| map_row(row) }
    end

    def map_row(row)
      attributes = map_columns(row)
      code = attributes[:code]

      attributes.merge(
        owner_whatsapp_at: yes_no(row, 'id_whatsapp_proprietario_doc', key: code, attribute: :owner_whatsapp_at),
        driver_whatsapp_at: yes_no(row, 'id_whatsapp_motorista', key: code, attribute: :driver_whatsapp_at),
        high_performance_at: yes_no(row, 'id_alto_desempenho', key: code, attribute: :high_performance_at),
        registered_month_on: convert(row, 'dt_mes_cadastro', :month_date, year: row['dt_ano_cadastro']),
        updated_month_on: convert(row, 'dt_mes_atualizacao', :month_date, year: row['dt_ano_atualizacao']),
        raw_data: row,
      )
    end
  end
end
