class Tenant < ApplicationRecord
  has_many :users, dependent: :restrict_with_error

  validates :name, :legal_id, :trade_name, presence: true
  validates :legal_id, uniqueness: true
end
