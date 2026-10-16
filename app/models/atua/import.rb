module Atua
  class Import < ApplicationRecord
    FILE_RETENTION = 60.days
    STATUSES = %i[pending running succeeded failed].freeze
    SOURCES = %i[mock production upload].freeze
    ERROR_TYPES = %i[configuration authentication session download spreadsheet layout conversion unexpected].freeze
    ACTION_REQUIRED_ERROR_TYPES = %w[configuration authentication layout].freeze
    LATEST_PER_REPORT_SQL = 'DISTINCT ON (atua_imports.tenant_id, atua_imports.report_type) atua_imports.id'.freeze

    belongs_to :tenant

    has_one_attached :file

    enum :report_type, Report::TYPES.index_with(&:to_s), validate: true
    enum :status_type, STATUSES.index_with(&:to_s), validate: true
    enum :source_type, SOURCES.index_with(&:to_s), prefix: :source, validate: { allow_nil: true }
    enum :error_type, ERROR_TYPES.index_with(&:to_s), prefix: :error, validate: { allow_nil: true }

    validates :rows_read, :inserted_count, :updated_count, :removed_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validate :end_date_not_before_start_date

    scope :by_tenant, ->(tenant_id) { where(tenant_id:) }
    scope :by_report_type, ->(report_type) { where(report_type:) }
    scope :by_status_type, ->(status_type) { where(status_type:) }
    scope :by_period_start, ->(date) { where(period_end_date.gteq(parse_date(date))) }
    scope :by_period_end, ->(date) { where(period_start_date.lteq(parse_date(date))) }
    scope :with_expired_file, -> { joins(:file_attachment).where(created_at: ...FILE_RETENTION.ago) }
    scope :requiring_action, -> { failed.where(error_type: ACTION_REQUIRED_ERROR_TYPES) }
    scope :latest_per_report, -> {
      where(id: unscoped.select(Arel.sql(LATEST_PER_REPORT_SQL)).order(:tenant_id, :report_type, created_at: :desc, id: :desc))
    }

    class << self
      def statuses
        status_types.keys.index_by { |status_type| human_enum_name(:status_type, status_type) }
      end

      def parse_date(value)
        Date.iso8601(value.to_s)
      rescue Date::Error
        nil
      end

      def period_start_date
        Arel::Nodes::NamedFunction.new('COALESCE', [arel_table[:start_date], created_on])
      end

      def period_end_date
        Arel::Nodes::NamedFunction.new('COALESCE', [arel_table[:end_date], created_on])
      end

      private

      def created_on
        utc_created_at = Arel::Nodes::NamedFunction.new('timezone', [Arel::Nodes.build_quoted('UTC'), arel_table[:created_at]])
        local_created_at = Arel::Nodes::NamedFunction.new('timezone', [Arel::Nodes.build_quoted(Time.zone.tzinfo.identifier), utc_created_at])

        Arel::Nodes::NamedFunction.new('DATE', [local_created_at])
      end
    end

    def start!
      update!(
        status_type: :running, started_at: Time.current, finished_at: nil, rows_read: 0, inserted_count: 0,
        updated_count: 0, removed_count: 0, error_message: nil, error_type: nil, warning_message: nil
      )
    end

    def succeed!(**counts)
      update!(status_type: :succeeded, finished_at: Time.current, error_message: nil, error_type: nil, **counts)
    end

    def fail!(message, error_type: :unexpected)
      update!(status_type: :failed, finished_at: Time.current, error_message: message, error_type:)
    end

    def period?
      start_date.present? && end_date.present?
    end

    def action_required?
      failed? && ACTION_REQUIRED_ERROR_TYPES.include?(error_type)
    end

    def duration
      return unless started_at && finished_at

      finished_at - started_at
    end

    def validate_reprocess
      if running?
        errors.add(:base, :running)
        return
      end

      unless file.attached?
        errors.add(:base, :missing_file)
        return
      end

      ReprocessImportJob.perform_later(id)
    end

    private

    def end_date_not_before_start_date
      return unless start_date && end_date && end_date < start_date

      errors.add(:end_date, :before_start_date)
    end
  end
end

# == Schema Information
#
# Table name: atua_imports
#
#  id              :bigint           not null, primary key
#  end_date        :date
#  error_message   :text
#  error_type      :enum
#  finished_at     :datetime
#  inserted_count  :integer          default(0), not null
#  removed_count   :integer          default(0), not null
#  report_type     :enum             not null
#  rows_read       :integer          default(0), not null
#  source_type     :enum
#  start_date      :date
#  started_at      :datetime
#  status_type     :enum             default("pending"), not null
#  updated_count   :integer          default(0), not null
#  warning_message :text
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  tenant_id       :bigint           not null
#
# Indexes
#
#  idx_on_tenant_id_report_type_finished_at_81434a2c5a             (tenant_id,report_type,finished_at)
#  index_atua_imports_on_status_type                               (status_type)
#  index_atua_imports_on_tenant_id_and_report_type_and_created_at  (tenant_id,report_type,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
