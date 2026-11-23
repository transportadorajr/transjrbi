class JobPosition < ApplicationRecord
  include Activatable
  include Sortable

  sortable :name

  belongs_to :tenant

  has_many :employees, dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: { scope: :tenant_id }

  scope :by_name, ->(name) { where(arel_table[:name].matches("%#{sanitize_sql_like(name)}%")) }

  class << self
    def statuses
      {
        I18n.t('job_positions.status.active') => :active,
        I18n.t('job_positions.status.inactive') => :deactivated,
      }
    end
  end
end

# == Schema Information
#
# Table name: job_positions
#
#  id           :bigint           not null, primary key
#  activated_at :datetime
#  name         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  tenant_id    :bigint           not null
#
# Indexes
#
#  index_job_positions_on_tenant_id           (tenant_id)
#  index_job_positions_on_tenant_id_and_name  (tenant_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
