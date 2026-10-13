class Access < ApplicationRecord
  PERMITTED_ATTRIBUTES = %i[resource_id reads creates].freeze
  READ_ABILITIES = %i[read].freeze
  WRITE_ABILITIES = %i[read create update destroy].freeze

  belongs_to :user
  belongs_to :resource
  belongs_to :tenant

  validates :resource_id, uniqueness: { scope: :user_id }

  def abilities
    return WRITE_ABILITIES if creates?
    return READ_ABILITIES if reads?

    []
  end

  def resource_symbol
    resource.slug.to_sym
  end
end

# == Schema Information
#
# Table name: accesses
#
#  id          :bigint           not null, primary key
#  creates     :boolean          default(FALSE), not null
#  reads       :boolean          default(FALSE), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  resource_id :bigint           not null
#  tenant_id   :bigint           not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_accesses_on_resource_id              (resource_id)
#  index_accesses_on_tenant_id                (tenant_id)
#  index_accesses_on_user_id                  (user_id)
#  index_accesses_on_user_id_and_resource_id  (user_id,resource_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (resource_id => resources.id)
#  fk_rails_...  (tenant_id => tenants.id)
#  fk_rails_...  (user_id => users.id)
#
