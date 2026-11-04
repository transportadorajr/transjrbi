class DistanceAdjustment < ApplicationRecord
  include Sortable

  sortable :transport_document_number, -> { numeric_number }
  sortable :distance_km, -> { arel_table[:distance_km] }
  sortable :applied_at, -> { arel_table[:applied_at] }

  belongs_to :tenant

  validates :transport_document_number, :distance_km, presence: true
  validates :transport_document_number, uniqueness: { scope: :tenant_id }
  validates :distance_km, numericality: { greater_than: 0 }

  scope :applied, -> { where.not(applied_at: nil) }
  scope :pending, -> { where(applied_at: nil) }
  scope :by_number, ->(number) { where(arel_table[:transport_document_number].matches("%#{sanitize_sql_like(number.to_s.strip)}%")) }
  scope :by_status, ->(status) { status.to_s == 'applied' ? applied : pending }

  class << self
    def numeric_number
      Arel::Nodes::NamedFunction.new('CAST', [arel_table[:transport_document_number].as(Arel.sql('numeric'))])
    end

    def statuses
      {
        I18n.t('distance_adjustments.index.applied') => :applied,
        I18n.t('distance_adjustments.index.pending') => :pending,
      }
    end

    def normalize_number(value)
      return value.to_i.to_s if value.is_a?(Numeric)

      value.to_s.strip.sub(/\A0+(?=\d)/, '')
    end
  end

  def applied?
    applied_at.present?
  end

  def transport_documents
    tenant.atua_transport_documents.where(number: transport_document_number)
  end
end

# == Schema Information
#
# Table name: distance_adjustments
#
#  id                        :bigint           not null, primary key
#  applied_at                :datetime
#  distance_km               :decimal(14, 2)   not null
#  transport_document_number :string           not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  tenant_id                 :bigint           not null
#
# Indexes
#
#  idx_on_tenant_id_transport_document_number_430c6a051e  (tenant_id,transport_document_number) UNIQUE
#  index_distance_adjustments_on_tenant_id                (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
