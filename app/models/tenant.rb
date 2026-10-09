class Tenant < ApplicationRecord
  has_many :users, dependent: :restrict_with_error

  validates :name, :legal_id, :trade_name, presence: true
  validates :legal_id, uniqueness: true
end

# == Schema Information
#
# Table name: tenants
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  trade_name :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  legal_id   :string           not null
#
# Indexes
#
#  index_tenants_on_legal_id  (legal_id) UNIQUE
#
