class Holiday < ApplicationRecord
  include Sortable

  SCOPES = %i[national state municipal].freeze
  KINDS = %i[holiday bridge_day optional].freeze

  sortable :date, -> { arel_table[:date] }
  sortable :name

  belongs_to :tenant

  enum :scope_type, SCOPES.index_with(&:to_s), validate: true
  enum :kind_type, KINDS.index_with(&:to_s), validate: true

  validates :date, :name, presence: true
  validates :date, uniqueness: { scope: :tenant_id }

  scope :by_year, ->(year) { where(date: Date.new(year.to_i).all_year) }
  scope :by_name, ->(name) { where(arel_table[:name].matches("%#{sanitize_sql_like(name)}%")) }
  scope :by_scope_type, ->(scope_type) { where(scope_type:) }
end

# == Schema Information
#
# Table name: holidays
#
#  id         :bigint           not null, primary key
#  date       :date             not null
#  kind_type  :enum             default("holiday"), not null
#  name       :string           not null
#  scope_type :enum             default("national"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  tenant_id  :bigint           not null
#
# Indexes
#
#  index_holidays_on_tenant_id           (tenant_id)
#  index_holidays_on_tenant_id_and_date  (tenant_id,date) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
