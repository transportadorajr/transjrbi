module Dashboard
  class ExportFacts
    UNKNOWN_COUNTRY = 'unknown'.freeze
    PLANT_PREFIX = 'plant'.freeze
    CITY_PREFIX = 'city'.freeze

    Fact = Data.define(:document_id, :number, :trip_on, :manifest_code, :manifest_number, :plate, :customer_group_id,
                       :origin_city, :origin_state, :recipient_name, :country, :tons, :plant_key, :plant_label)

    def initialize(documents:, manifests:, customers:, plants:, customer_groups:)
      @documents = documents
      @manifests = manifests
      @customers = customers
      @plants = plants
      @customer_groups = customer_groups
    end

    def call(range)
      rows = pluck(range)
      customer_data = customer_data_for(rows)

      rows.filter_map do |document_id, number, trip_on, manifest_code, manifest_number, plate, taker_code, recipient_code, recipient_name,
                          origin_city, origin_state, tons|
        customer_group_id = customer_data.dig(taker_code, :customer_group_id)
        next unless customer_group_ids.include?(customer_group_id)

        plant_key, plant_label = plant_for(customer_group_id, origin_city, origin_state)

        Fact.new(document_id:, number:, trip_on:, manifest_code:, manifest_number:, plate:, customer_group_id:, origin_city:, origin_state:,
                 recipient_name:, country: customer_data.dig(recipient_code, :country) || UNKNOWN_COUNTRY, tons: tons.to_d, plant_key:,
                 plant_label:)
      end
    end

    private

    attr_reader :documents, :manifests, :customers, :plants, :customer_groups

    def customer_group_ids
      @customer_group_ids ||= customer_groups.ids.to_set
    end

    def pluck(range)
      manifests.trips
        .where(Arel.sql(Atua::Manifest.trip_on_sql).between(range))
        .joins("INNER JOIN LATERAL (#{export_documents.to_sql}) export_documents ON TRUE")
        .order(Arel.sql(Atua::Manifest.trip_on_sql), :code, Arel.sql('export_documents.number'))
        .pluck(Arel.sql('export_documents.id'), Arel.sql('export_documents.number'), Arel.sql(Atua::Manifest.trip_on_sql), :code, :number,
               :plate, Arel.sql('export_documents.taker_code'), Arel.sql('export_documents.recipient_code'),
               Arel.sql('export_documents.recipient_name'), Arel.sql('export_documents.origin_city'),
               Arel.sql('export_documents.origin_state'), Arel.sql('export_documents.tons'))
    end

    def export_documents
      table = Atua::TransportDocument.arel_table
      tons = Arel::Nodes::NamedFunction.new('COALESCE', [table[:weight_tons], Arel::Nodes::Division.new(table[:weight_kg], 1000),
                                                         Arel::Nodes.build_quoted(0)])

      Atua::Manifest.first_trip_documents.merge(documents.export_loadings)
        .select(table[:id], table[:number], table[:taker_code], table[:recipient_code], table[:recipient_name], table[:origin_city],
                table[:origin_state], tons.as('tons'))
    end

    def customer_data_for(rows)
      codes = rows.flat_map { |row| [row[6], row[7]] }.compact.uniq

      customers.where(code: codes).pluck(:code, :customer_group_id, :country_type).to_h do |code, customer_group_id, country|
        [code, { customer_group_id:, country: }]
      end
    end

    def plant_for(customer_group_id, origin_city, origin_state)
      plant = plants_by_group.fetch(customer_group_id, []).find { |candidate| candidate.serves_city?(origin_city) }
      return ["#{PLANT_PREFIX}-#{plant.id}", plant.name] if plant

      label = I18n.t('tax.city', city: origin_city.to_s, state: origin_state.to_s)
      ["#{CITY_PREFIX}-#{CustomerGroup.compact(origin_city)}-#{origin_state}", label]
    end

    def plants_by_group
      @plants_by_group ||= plants.order(:name, :id).to_a.group_by(&:customer_group_id)
    end
  end
end
