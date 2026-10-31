class CustomerGroup < ApplicationRecord
  include Sortable

  sortable :name

  belongs_to :tenant

  has_many :customers, class_name: 'Atua::Customer', inverse_of: :customer_group, dependent: :restrict_with_error
  has_many :commission_rules, inverse_of: :customer_group, dependent: :restrict_with_error
  has_many :tonnage_rates, inverse_of: :customer_group, dependent: :restrict_with_error

  time_based_flag :activated

  validates :name, presence: true, uniqueness: { scope: :tenant_id }

  scope :by_name, ->(name) { where(arel_table[:name].matches("%#{sanitize_sql_like(name)}%")) }
  scope :by_status, ->(status) { status.to_s == 'active' ? activated : not_activated }
  scope :with_terms, -> { where.not(terms: []) }

  class << self
    def statuses
      {
        I18n.t('customer_groups.index.active') => :active,
        I18n.t('customer_groups.index.deactivated') => :deactivated,
      }
    end

    def compact(text)
      I18n.transliterate(text.to_s).upcase.gsub(/[^A-Z0-9]/, '')
    end

    def for_name(*names)
      with_terms.order(:id).find { |group| group.match?(*names) }
    end
  end

  def match?(*names)
    compacted_names = names.map { |name| self.class.compact(name) }.compact_blank

    compacted_terms.any? { |term| compacted_names.any? { |name| name.include?(term) } }
  end

  private

  def compacted_terms
    terms.map { |term| self.class.compact(term) }.compact_blank
  end
end

# == Schema Information
#
# Table name: customer_groups
#
#  id           :bigint           not null, primary key
#  activated_at :datetime
#  name         :string           not null
#  terms        :string           default([]), not null, is an Array
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  tenant_id    :bigint           not null
#
# Indexes
#
#  index_customer_groups_on_tenant_id           (tenant_id)
#  index_customer_groups_on_tenant_id_and_name  (tenant_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
