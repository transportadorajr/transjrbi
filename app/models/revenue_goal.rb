class RevenueGoal < ApplicationRecord
  TARGET_TYPES = %w[company vehicle customer_group].freeze
  MONTH_FORMAT = '%Y-%m'.freeze

  belongs_to :tenant
  belongs_to :customer_group, optional: true, inverse_of: :revenue_goals

  enum :target_type, TARGET_TYPES.index_with(&:itself), validate: true

  monetize :amount_cents

  validates :month, presence: true
  validates :amount_cents, numericality: { greater_than: 0 }
  validates :plate, presence: true, if: :vehicle?
  validates :plate, absence: true, unless: :vehicle?
  validates :customer_group, presence: true, if: :customer_group?
  validates :customer_group_id, absence: true, unless: :customer_group?
  validates :target_type, uniqueness: { scope: %i[tenant_id month plate customer_group_id] }

  before_validation :normalize_month
  before_validation :normalize_plate

  scope :for_month, ->(month) { where(month: month.beginning_of_month) }

  class << self
    def parse_month(value)
      Date.strptime(value.to_s.strip.first(7), MONTH_FORMAT)
    rescue Date::Error
      nil
    end
  end

  private

  def normalize_month
    self.month = month&.beginning_of_month
  end

  def normalize_plate
    self.plate = plate.present? ? Atua::TransportDocument.normalize_plate(plate) : nil
  end
end

# == Schema Information
#
# Table name: revenue_goals
#
#  id                :bigint           not null, primary key
#  amount_cents      :bigint           not null
#  month             :date             not null
#  plate             :string
#  target_type       :enum             not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  customer_group_id :bigint
#  tenant_id         :bigint           not null
#
# Indexes
#
#  index_revenue_goals_on_customer_group_id  (customer_group_id)
#  index_revenue_goals_on_target             (tenant_id,month,target_type,plate,customer_group_id) UNIQUE NULLS NOT DISTINCT
#  index_revenue_goals_on_tenant_id          (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (customer_group_id => customer_groups.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
