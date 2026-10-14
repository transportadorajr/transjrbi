module Atua
  class Import < ApplicationRecord
    FILE_RETENTION = 60.days
    STATUSES = %i[pending running succeeded failed].freeze

    belongs_to :tenant

    has_one_attached :file

    enum :report_type, Report::TYPES.index_with(&:to_s), validate: true
    enum :status_type, STATUSES.index_with(&:to_s), validate: true

    validates :rows_read, :inserted_count, :updated_count, :removed_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validate :end_date_not_before_start_date

    scope :by_report_type, ->(report_type) { where(report_type:) }
    scope :by_status_type, ->(status_type) { where(status_type:) }
    scope :with_expired_file, -> { joins(:file_attachment).where(created_at: ...FILE_RETENTION.ago) }

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
#  id             :bigint           not null, primary key
#  end_date       :date
#  error_message  :text
#  finished_at    :datetime
#  inserted_count :integer          default(0), not null
#  removed_count  :integer          default(0), not null
#  report_type    :enum             not null
#  rows_read      :integer          default(0), not null
#  start_date     :date
#  started_at     :datetime
#  status_type    :enum             default("pending"), not null
#  updated_count  :integer          default(0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  tenant_id      :bigint           not null
#
# Indexes
#
#  index_atua_imports_on_status_type                               (status_type)
#  index_atua_imports_on_tenant_id_and_report_type_and_created_at  (tenant_id,report_type,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
