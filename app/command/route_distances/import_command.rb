module RouteDistances
  class ImportCommand
    READ_ERRORS = [ArgumentError, IOError, TypeError, Roo::Error, Zip::Error, Ole::Storage::FormatError].freeze

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
      @errors = []
    end

    def call
      RouteDistance.transaction do
        each_row { |line, values| import_row(line, *values) }
        ApplyCommand.call(tenant)
      end

      Result.new(created: counts[:created], updated: counts[:updated], documents:, errors:)
    rescue *READ_ERRORS => e
      Result.new(created: 0, updated: 0, documents: 0, errors: [I18n.t('route_distances.import.unreadable', reason: e.message)])
    end

    private

    attr_reader :tenant, :path, :extension, :counts, :route_ids, :errors

    def each_row
      sheet = Roo::Spreadsheet.open(path.to_s, extension: extension.delete('.').to_sym).sheet(0)
      return if sheet.last_row.nil?

      (sheet.first_row..sheet.last_row).each do |line|
        values = sheet.row(line).first(6)
        next if values.all? { |value| value.to_s.strip.empty? }
        next if line == sheet.first_row && header?(values.last)

        yield line, values
      end
    end

    def header?(value)
      value.is_a?(String) && value.match?(/[[:alpha:]]/)
    end

    def import_row(line, document, origin_city, origin_state, destination_city, destination_state, distance)
      customer = customer_for(document)
      if customer.nil?
        errors << row_error(line, I18n.t('route_distances.import.unknown_customer', document:))
        return
      end

      attributes = { customer_code: customer.code.to_s, origin_city:, origin_state:, destination_city:, destination_state:,
                     distance_km: distance_text(distance) }
      existing = find_route(attributes)
      form = build_form(existing, attributes)

      if form.save
        counts[existing ? :updated : :created] += 1
        route_ids << form.id
      else
        errors << row_error(line, form.errors.full_messages.to_sentence)
      end
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
