class EmergencyContact < ApplicationRecord
  RELATIONSHIPS = %i[spouse partner fiance mother father child sibling godparent other].freeze
  NATIONAL_PHONE_LENGTHS = (10..11)
  INTERNATIONAL_PHONE_LENGTHS = (12..15)
  INTERNATIONAL_PREFIX = '+'.freeze

  belongs_to :tenant
  belongs_to :employee

  enum :relationship_type, RELATIONSHIPS.index_with(&:to_s), validate: { allow_nil: true }

  validates :name, presence: true
  validates :position, numericality: { only_integer: true, greater_than: 0 }

  class << self
    def normalize_phone(value)
      digits = value.to_s.gsub(/\D/, '')
      return if digits.empty?

      value.to_s.strip.start_with?(INTERNATIONAL_PREFIX) ? "#{INTERNATIONAL_PREFIX}#{digits}" : digits
    end

    def valid_phone?(phone)
      return INTERNATIONAL_PHONE_LENGTHS.cover?(phone.size - 1) if international_phone?(phone)

      NATIONAL_PHONE_LENGTHS.cover?(phone.size)
    end

    def international_phone?(phone)
      phone.to_s.start_with?(INTERNATIONAL_PREFIX)
    end
  end
end

# == Schema Information
#
# Table name: emergency_contacts
#
#  id                :bigint           not null, primary key
#  name              :string           not null
#  notes             :text
#  phone             :string
#  position          :integer          default(1), not null
#  relationship_type :enum
#  secondary_phone   :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  employee_id       :bigint           not null
#  tenant_id         :bigint           not null
#
# Indexes
#
#  index_emergency_contacts_on_employee_id  (employee_id)
#  index_emergency_contacts_on_tenant_id    (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (employee_id => employees.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
