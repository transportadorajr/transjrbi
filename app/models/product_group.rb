class ProductGroup < ApplicationRecord
  include Sortable

  sortable :name

  belongs_to :tenant
  belongs_to :parent, class_name: 'ProductGroup', optional: true, inverse_of: :subgroups

  has_many :subgroups, class_name: 'ProductGroup', foreign_key: :parent_id, inverse_of: :parent, dependent: :restrict_with_error
  has_many :transport_documents, class_name: 'Atua::TransportDocument', inverse_of: :product_group, dependent: :nullify

  time_based_flag :activated

  validates :name, presence: true, uniqueness: { scope: %i[tenant_id parent_id] }
  validate :parent_must_be_a_group

  scope :groups, -> { where(parent_id: nil) }
  scope :nested, -> { where.not(parent_id: nil) }
  scope :by_name, ->(name) { where(arel_table[:name].matches("%#{sanitize_sql_like(name)}%")) }
  scope :by_status, ->(status) { status.to_s == 'active' ? activated : not_activated }
  scope :classifying, -> { nested.activated.where(parent_id: unscoped.groups.activated.select(:id)) }

  class << self
    delegate :compact, to: :CustomerGroup

    def statuses
      {
        I18n.t('product_groups.index.active') => :active,
        I18n.t('product_groups.index.deactivated') => :deactivated,
      }
    end
  end

  def group?
    parent_id.nil?
  end

  def compacted_product_names
    product_names.map { |product_name| self.class.compact(product_name) }.compact_blank
  end

  private

  def parent_must_be_a_group
    return if parent.nil? || (parent.group? && parent.tenant_id == tenant_id && parent != self)

    errors.add(:parent, :invalid)
  end
end

# == Schema Information
#
# Table name: product_groups
#
#  id            :bigint           not null, primary key
#  activated_at  :datetime
#  name          :string           not null
#  product_names :string           default([]), not null, is an Array
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  parent_id     :bigint
#  tenant_id     :bigint           not null
#
# Indexes
#
#  index_product_groups_on_parent_id                         (parent_id)
#  index_product_groups_on_tenant_id                         (tenant_id)
#  index_product_groups_on_tenant_id_and_parent_id_and_name  (tenant_id,parent_id,name) UNIQUE NULLS NOT DISTINCT
#
# Foreign Keys
#
#  fk_rails_...  (parent_id => product_groups.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
