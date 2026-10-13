module Atua
  class MapManifestsCommand < MapReportCommand
    REPORT = 'rel_manifesto_detalhado'.freeze
    TRIP_START = %r{In[ií]cio da viagem:\s*(\d{2}/\d{2}/\d{4} \d{2}:\d{2})}i
    COLUMNS = {
      'cd_manifesto' => %i[code integer],
      'id_modelo' => %i[model integer],
      'nr_manifesto' => %i[number integer],
      'ds_serie' => %i[series integer],
      'nm_filial' => %i[branch_name string],
      'uf_empresa' => %i[company_state string],
      'cidade_empresa' => %i[company_city string],
      'dt_emissao' => %i[issued_on date],
      'dt_saida' => %i[departure_on date],
      'ds_observacao' => %i[notes string],
      'ds_placa' => %i[plate plate],
      'nr_chave' => %i[access_key string],
      'vl_total_nfe_mdfe' => %i[goods_value_cents cents],
      'ds_situacao' => %i[status string],
    }.freeze
    DOCUMENT_ATTRIBUTE_COLUMNS = {
      'nr_nota_fiscal' => %i[goods_invoice_numbers list],
      'vl_nota_fiscal' => %i[goods_value_cents cents],
      'vl_peso' => %i[weight_kg decimal],
      'qt_produto' => %i[weight_tons decimal],
      'vl_total' => %i[freight_cents cents],
      'id_frete' => %i[freight_payment string],
      'nm_remetente' => %i[sender_name string],
      'nm_destinatario' => %i[recipient_name string],
      'nm_agencia_origem' => %i[origin_agency_name string],
      'vl_km_calculado' => %i[calculated_distance_km decimal],
      'vl_km_doc' => %i[document_distance_km decimal],
    }.freeze
    SPECIAL_COLUMNS = %w[dt_encerramento hr_encerramento nr_ctrc nm_cidade_origem nm_cidade_destino].freeze
    REQUIRED_COLUMNS = %w[cd_manifesto nr_manifesto ds_serie nm_filial dt_emissao ds_situacao ds_observacao nr_ctrc vl_total].freeze

    class << self
      def known_columns
        super + DOCUMENT_ATTRIBUTE_COLUMNS.keys
      end
    end

    private

    def map(rows)
      rows.group_by { |row| convert(row, 'cd_manifesto', :integer) }.values.map do |manifest_rows|
        map_manifest(manifest_rows)
      end
    end

    def map_manifest(rows)
      header = rows.first
      attributes = map_columns(header)

      attributes.merge(
        trip_started_at: trip_started_at(attributes[:notes]),
        closed_at: convert_value(header['dt_encerramento'], :datetime, column: 'dt_encerramento', time: header['hr_encerramento']),
        raw_data: header,
        documents: rows.map { |row| map_document(row, attributes) },
      )
    end

    def map_document(row, manifest)
      attributes = DOCUMENT_ATTRIBUTE_COLUMNS.each_with_object({}) do |(column, (attribute, type)), mapped|
        mapped[attribute] = convert(row, column, type)
      end
      number, series = convert(row, 'nr_ctrc', :number_series)
      origin_state, origin_city = convert(row, 'nm_cidade_origem', :state_city)
      destination_state, destination_city = convert(row, 'nm_cidade_destino', :state_city)

      attributes.merge(
        manifest_code: manifest[:code],
        branch_name: manifest[:branch_name],
        transport_document_number: number,
        transport_document_series: series,
        origin_state:,
        origin_city:,
        destination_state:,
        destination_city:,
        raw_data: row,
      )
    end

    def trip_started_at(notes)
      match = TRIP_START.match(notes.to_s)
      match && convert_value(match[1], :datetime, column: 'ds_observacao')
    end
  end
end
