module RevenueProjection
  class Snapshot < ApplicationRecord
    PERIOD_TYPES = %i[month week].freeze

    belongs_to :tenant

    enum :period_type, PERIOD_TYPES.index_with(&:to_s), validate: true

    validates :period_start, :period_end, :taken_on, :reference_at, presence: true

    def realized
      Money.from_cents(realized_cents)
    end

    def projected
      Money.from_cents(projected_cents)
    end

    def low
      Money.from_cents(low_cents)
    end

    def high
      Money.from_cents(high_cents)
    end
  end
end

# == Schema Information
#
# Table name: revenue_projection_snapshots
#
#  id              :bigint           not null, primary key
#  days            :jsonb            not null
#  high_cents      :bigint           default(0), not null
#  low_cents       :bigint           default(0), not null
#  period_end      :date             not null
#  period_start    :date             not null
#  period_type     :enum             not null
#  projected_cents :bigint           default(0), not null
#  realized_cents  :bigint           default(0), not null
#  reconstructed   :boolean          default(FALSE), not null
#  reference_at    :datetime         not null
#  taken_on        :date             not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  tenant_id       :bigint           not null
#
# Indexes
#
#  idx_on_tenant_id_period_type_period_start_taken_on_fad3550f68  (tenant_id,period_type,period_start,taken_on) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
