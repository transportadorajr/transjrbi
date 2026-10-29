class ExcludedIssuer < ApplicationRecord
  belongs_to :tenant

  validates :code, :name, presence: true
  validates :code, uniqueness: { scope: :tenant_id }

  scope :by_name, ->(name) { where(arel_table[:name].matches("%#{sanitize_sql_like(name)}%")) }
  scope :with_document_totals, -> {
    documents = Atua::TransportDocument.active.not_canceled
      .where(Atua::TransportDocument.arel_table[:tenant_id].eq(arel_table[:tenant_id]))
      .where(Atua::TransportDocument.arel_table[:issuer_code].eq(arel_table[:code]))

    select(
      arel_table[Arel.star],
      Arel::Nodes::Grouping.new(documents.select(Arel.star.count).arel).as('documents_count'),
      Arel::Nodes::Grouping.new(documents.select(Atua::TransportDocument.arel_table[:freight_cents].sum).arel).as('freight_cents'),
    )
  }

  class << self
    def available_issuers(tenant)
      tenant.atua_transport_documents
        .where.not(issuer_code: nil)
        .where.not(issuer_code: tenant.excluded_issuers.select(:code))
        .group(:issuer_code)
        .order(Arel.sql('MAX(issuer_name)'), :issuer_code)
        .pluck(Arel.sql('MAX(issuer_name)'), :issuer_code)
    end
  end

  def freight
    Money.from_cents(self[:freight_cents].to_i)
  end
end

# == Schema Information
#
# Table name: excluded_issuers
#
#  id         :bigint           not null, primary key
#  code       :integer          not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  tenant_id  :bigint           not null
#
# Indexes
#
#  index_excluded_issuers_on_tenant_id           (tenant_id)
#  index_excluded_issuers_on_tenant_id_and_code  (tenant_id,code) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
