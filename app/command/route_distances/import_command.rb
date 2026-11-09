module RouteDistances
  class ImportCommand
    READ_ERRORS = [ArgumentError, IOError, TypeError, Roo::Error, Zip::Error, Ole::Storage::FormatError].freeze
    DOCUMENT_NUMBER_COLUMNS = 2
    ROUTE_COLUMNS = 6
    ROUTE_FIELDS = %i[taker_code origin_city origin_state destination_city destination_state].freeze

    Result = Data.define(:created, :updated, :documents, :errors)

    class << self
      def call(tenant, path, extension)
        new(tenant, path, extension).call
      end
    end

    def initialize(tenant, path, extension)
      @tenant = tenant
      @path = path
      @extension = extension
      @counts = Hash.new(0)
      @route_ids = []
      @imported_routes = {}
      @errors = []
    end

    def call
      RouteDistance.transaction do
        each_row { |line, values| import_row(line, values) }
        ApplyCommand.call(tenant)
      end

      Result.new(created: counts[:created], updated: counts[:updated], documents:, errors:)
    rescue *READ_ERRORS => e
      Result.new(created: 0, updated: 0, documents: 0, errors: [I18n.t('route_distances.import.unreadable', reason: e.message)])
    end

    private

    attr_reader :tenant, :path, :extension, :counts, :route_ids, :imported_routes, :errors, :by_document_number

    def each_row
      sheet = Roo::Spreadsheet.open(path.to_s, extension: extension.delete('.').to_sym).sheet(0)
      return if sheet.last_row.nil?

      @by_document_number = sheet.last_column.to_i <= DOCUMENT_NUMBER_COLUMNS
      columns = by_document_number ? DOCUMENT_NUMBER_COLUMNS : ROUTE_COLUMNS

      (sheet.first_row..sheet.last_row).each do |line|
        values = sheet.row(line).first(columns)
        next if values.all? { |value| value.to_s.strip.empty? }
        next if line == sheet.first_row && header?(values.last)

        yield line, values
      end
    end

    def header?(value)
      value.is_a?(String) && value.match?(/[[:alpha:]]/)
    end

    def import_row(line, values)
      attributes = by_document_number ? document_route(line, *values) : customer_route(line, *values)
      save_route(line, attributes) if attributes
    end

    def customer_route(line, document, origin_city, origin_state, destination_city, destination_state, distance)
      customer = customer_for(document)
      if customer.nil?
        errors << row_error(line, I18n.t('route_distances.import.unknown_customer', document:))
        return
      end

      { customer_code: customer.code.to_s, origin_city:, origin_state:, destination_city:, destination_state:,
        distance_km: distance_text(distance) }
    end

    def document_route(line, number, distance)
      number = document_number(number)
      routes = tenant.atua_transport_documents.where(number:).pluck(*ROUTE_FIELDS).uniq { |route| RouteDistance.route_key(*route) }

      if routes.size == 1
        customer_code, origin_city, origin_state, destination_city, destination_state = routes.first
        return { customer_code: customer_code.to_s, origin_city:, origin_state:, destination_city:, destination_state:,
                 distance_km: distance_text(distance) }
      end

      key = if number.empty? then 'blank_document'
            elsif routes.empty? then 'unknown_document'
            else 'ambiguous_document'
            end
      errors << row_error(line, I18n.t("route_distances.import.#{key}", number:))
      nil
    end

    def document_number(number)
      text = number.is_a?(Numeric) ? number.to_i.to_s : number.to_s.strip
      text.match?(/\A\d+\z/) ? text.sub(/\A0+(?=\d)/, '') : text
    end

    def save_route(line, attributes)
      existing = find_route(attributes)
      form = build_form(existing, attributes)
      return unless route_not_imported_yet?(line, form)

      if form.save
        counts[existing ? :updated : :created] += 1
        route_ids << form.id
        imported_routes[form.route_distance.route_key] = [line, form.route_distance.distance_km]
      else
        errors << row_error(line, form.errors.full_messages.to_sentence)
      end
    end

    def route_not_imported_yet?(line, form)
      return true unless form.valid?

      previous_line, previous_distance = imported_routes[route_key(form)]
      return true if previous_line.nil?
      return false if previous_distance == form.distance_km_value

      distance = RouteDistanceForm.format_distance(previous_distance)
      errors << row_error(line, I18n.t('route_distances.import.conflicting_distance', line: previous_line, distance:))
      false
    end

    def route_key(form)
      RouteDistance.route_key(form.customer_code.to_i, form.origin_city, form.origin_state, form.destination_city, form.destination_state)
    end

    def customer_for(document)
      digits = document.is_a?(Numeric) ? document.to_i.to_s : document.to_s.gsub(/\D/, '')
      return if digits.empty?

      customers = tenant.atua_customers.where(document_digits: [digits, digits.rjust(14, '0'), digits.rjust(11, '0')].uniq)
      customers.where(code: tenant.atua_transport_documents.select(:taker_code)).order(:code).first || customers.order(:code).first
    end

    def find_route(attributes)
      route = attributes.slice(:origin_city, :origin_state, :destination_city, :destination_state)
        .transform_values { |value| RouteDistance.normalize_city(value) }

      tenant.route_distances.find_by(customer_code: attributes[:customer_code], **route)
    end

    def build_form(existing, attributes)
      form = existing ? RouteDistanceForm.for_route_distance(existing) : RouteDistanceForm.new(tenant:)
      form.assign_attributes(attributes)
      form.batch_import = true
      form
    end

    def distance_text(distance)
      distance.is_a?(Numeric) ? RouteDistanceForm.format_distance(distance.to_d) : distance.to_s
    end

    def documents
      tenant.atua_transport_documents.where(route_distance_id: route_ids.uniq).count
    end

    def row_error(line, message)
      I18n.t('route_distances.import.row_error', line:, message:)
    end
  end
end
