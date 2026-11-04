module DistanceAdjustments
  class ImportCommand
    READ_ERRORS = [ArgumentError, IOError, TypeError, Roo::Error, Zip::Error, Ole::Storage::FormatError].freeze

    Result = Data.define(:created, :updated, :applied, :pending, :duplicated_numbers, :errors)

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
      @duplicated_numbers = []
      @errors = []
    end

    def call
      each_row { |line, number, distance| import_row(line, number, distance) }

      Result.new(created: counts[:created], updated: counts[:updated], applied: counts[:applied], pending: counts[:pending],
                 duplicated_numbers:, errors:)
    rescue *READ_ERRORS => e
      Result.new(created: 0, updated: 0, applied: 0, pending: 0, duplicated_numbers: [],
                 errors: [I18n.t('distance_adjustments.import.unreadable', reason: e.message)])
    end

    private

    attr_reader :tenant, :path, :extension, :counts, :duplicated_numbers, :errors

    def each_row
      sheet = Roo::Spreadsheet.open(path.to_s, extension: extension.delete('.').to_sym).sheet(0)
      return if sheet.last_row.nil?

      (sheet.first_row..sheet.last_row).each do |line|
        number, distance = sheet.row(line).first(2)
        next if [number, distance].all? { |value| value.to_s.strip.empty? }
        next if line == sheet.first_row && header?(number)

        yield line, number, distance
      end
    end

    def header?(value)
      value.is_a?(String) && value.match?(/[[:alpha:]]/)
    end

    def import_row(line, number, distance)
      existing = tenant.distance_adjustments.find_by(transport_document_number: DistanceAdjustment.normalize_number(number))
      form = build_form(existing, number, distance)

      if form.save
        count(form, existing)
      else
        errors << I18n.t('distance_adjustments.import.row_error', line:, message: form.errors.full_messages.to_sentence)
      end
    end

    def build_form(existing, number, distance)
      distance_km = distance.is_a?(Numeric) ? DistanceAdjustmentForm.format_distance(distance.to_d) : distance.to_s
      return DistanceAdjustmentForm.for_distance_adjustment(existing).tap { |form| form.distance_km = distance_km } if existing

      DistanceAdjustmentForm.new(tenant:, transport_document_number: DistanceAdjustment.normalize_number(number), distance_km:)
    end

    def count(form, existing)
      counts[existing ? :updated : :created] += 1
      counts[form.documents_count.positive? ? :applied : :pending] += 1
      duplicated_numbers << form.transport_document_number if form.documents_count > 1
    end
  end
end
