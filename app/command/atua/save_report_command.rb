module Atua
  class SaveReportCommand
    BATCH_SIZE = 500
    MINIMUM_RECEIVED_RATIO = 0.5
    UNIQUE_BY = %i[tenant_id code].freeze
    INSERTED_FLAG = Arel.sql('(xmax = 0) AS inserted')
    MODEL = nil
    MAPPER = nil
    PREVIOUS_ATTRIBUTES = [].freeze
    CHILDREN = [].freeze

    Result = Data.define(:inserted, :updated, :removed, :warning)

    class << self
      def call(import, spreadsheet)
        new(import, spreadsheet).call
      end

      def for(report_type)
        "Atua::Save#{report_type.to_s.camelize}Command".constantize
      end
    end

    def initialize(import, spreadsheet)
      @import = import
      @spreadsheet = spreadsheet
      @imported_at = Time.current
    end

    def call
      records = map_records
      existing_count = removal_scope&.active&.count
      inserted, updated = upsert(model, records.map { |record| import_attributes(record.except(*self.class::CHILDREN)) })
      save_children(records)
      removed, warning = mark_removed(records.size, existing_count)

      Result.new(inserted:, updated:, removed:, warning:)
    end

    private

    attr_reader :import, :spreadsheet, :imported_at

    delegate :tenant, :tenant_id, to: :import

    def model
      self.class::MODEL
    end

    def map_records
      self.class::MAPPER.call(tenant, spreadsheet, previous:).index_by { |record| record[:code] }.values
    end

    def previous
      attributes = self.class::PREVIOUS_ATTRIBUTES
      return {} if attributes.empty?

      model.where(tenant_id:, code: source_codes).pluck(:code, *attributes).to_h do |code, *values|
        [code, attributes.zip(values).to_h]
      end
    end

    def source_codes
      column = self.class::MAPPER::COLUMNS.key(%i[code integer])

      spreadsheet.rows.filter_map { |row| source_code(row[column]) }.uniq
    end

    def source_code(value)
      ConvertValueCommand.call(tenant, value, :integer)
    rescue ConversionError
      nil
    end

    def import_attributes(attributes)
      attributes.merge(tenant_id:, atua_import_id: import.id, imported_at:, removed_from_atua_at: nil)
    end

    def upsert(target, rows, unique_by: UNIQUE_BY)
      rows.each_slice(BATCH_SIZE).reduce([0, 0]) do |(inserted, updated), batch|
        flags = target.upsert_all(batch, unique_by:, returning: INSERTED_FLAG).rows.flatten
        batch_inserted = flags.count(true)

        [inserted + batch_inserted, updated + batch.size - batch_inserted]
      end
    end

    def replace(target, scope, rows)
      scope.delete_all
      rows.each_slice(BATCH_SIZE) { |batch| target.insert_all(batch) }
    end

    def save_children(records); end

    def mark_children_removed(codes); end

    def removal_scope
      scope = model.where(tenant_id:)
      return scope unless Report.find(import.report_type).period?
      return unless import.period?

      scope.by_period(import.start_date, import.end_date)
    end

    def mark_removed(received_count, existing_count)
      return [0, warn(I18n.t('atua.warnings.missing_period'))] if existing_count.nil?

      if too_few_received?(received_count, existing_count)
        message = I18n.t('atua.warnings.removals_skipped', received: received_count, existing: existing_count)
        return [0, warn(message)]
      end

      missing = removal_scope.active.where(model.arel_table[:atua_import_id].is_distinct_from(import.id))
      codes = missing.pluck(:code)
      mark_children_removed(codes)

      [missing.update_all(removed_from_atua_at: imported_at, updated_at: imported_at), nil]
    end

    def too_few_received?(received_count, existing_count)
      existing_count.positive? && received_count < existing_count * MINIMUM_RECEIVED_RATIO
    end

    def warn(message)
      Rails.logger.warn("[Atua] Import #{import.id} (#{import.report_type}): #{message}")
      message
    end
  end
end
