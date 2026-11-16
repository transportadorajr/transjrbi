class RevenueGoal < ApplicationRecord
  TARGET_TYPES = %w[company vehicle customer_group region driver].freeze
  TARGET_COLUMNS = { 'vehicle' => :plate, 'customer_group' => :customer_group_id, 'region' => :macro_region_id, 'driver' => :driver_code }.freeze
  MONTH_FORMAT = '%Y-%m'.freeze

  belongs_to :tenant
  belongs_to :customer_group, optional: true, inverse_of: :revenue_goals
  belongs_to :macro_region, optional: true, inverse_of: :revenue_goals

  enum :target_type, TARGET_TYPES.index_with(&:itself), validate: true

  monetize :amount_cents

  validates :month, presence: true
  validates :amount_cents, numericality: { greater_than: 0 }
  validates :plate, presence: true, if: :vehicle?
  validates :plate, absence: true, unless: :vehicle?
  validates :customer_group, presence: true, if: :customer_group?
  validates :customer_group_id, absence: true, unless: :customer_group?
  validates :macro_region, presence: true, if: :region?
  validates :macro_region_id, absence: true, unless: :region?
  validates :driver_code, presence: true, if: :driver?
  validates :driver_code, absence: true, unless: :driver?
  validates :target_type, uniqueness: { scope: %i[tenant_id month plate customer_group_id macro_region_id driver_code] }

  before_validation :normalize_month
  before_validation :normalize_plate

  scope :for_month, ->(month) { where(month: month.beginning_of_month) }

  class << self
    def listed_customer_groups(tenant, goal_group_ids)
      tenant.customer_groups.where(id: goal_group_ids).or(tenant.customer_groups.activated).order(:name, :id)
    end

    def parse_month(value)
      Date.strptime(value.to_s.strip.first(7), MONTH_FORMAT)
    rescue Date::Error
      nil
    end
  end

  def target_key
    [target_type, *TARGET_COLUMNS.values.map { |column| self[column] }]
  end

  def target_value
    self[TARGET_COLUMNS[target_type]] if TARGET_COLUMNS.key?(target_type)
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
#  driver_code       :bigint
#  month             :date             not null
#  plate             :string
#  target_type       :enum             not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  customer_group_id :bigint
#  macro_region_id   :bigint
#  tenant_id         :bigint           not null
#
# Indexes
#
#  index_revenue_goals_on_customer_group_id  (customer_group_id)
#  index_revenue_goals_on_macro_region_id    (macro_region_id)
#  index_revenue_goals_on_target             (tenant_id,month,target_type,plate,customer_group_id,macro_region_id,driver_code) UNIQUE NULLS NOT DISTINCT
#  index_revenue_goals_on_tenant_id          (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (customer_group_id => customer_groups.id)
#  fk_rails_...  (macro_region_id => macro_regions.id) ON DELETE => cascade
#  fk_rails_...  (tenant_id => tenants.id)
#
