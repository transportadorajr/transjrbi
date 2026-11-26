class CustomerGroupAssignmentForm < BaseForm
  attribute :customer_group_id, :integer

  validates :customer_group_id, presence: true
  validate :customer_group_must_be_active

  attr_accessor :customer

  delegate :id, :tenant, to: :customer

  class << self
    def for_customer(customer)
      new(customer:, customer_group_id: customer.customer_group_id)
    end
  end

  def persisted?
    true
  end

  def to_param
    id.to_s
  end

  def customer_groups
    tenant.customer_groups.activated.order(:name, :id)
  end

  def submit
    Customers::UpdateCustomerGroupCommand.call(customer, customer_group)
  end

  private

  def customer_group
    return @customer_group if defined?(@customer_group)

    @customer_group = customer_groups.find_by(id: customer_group_id)
  end

  def customer_group_must_be_active
    return if customer_group_id.blank? || customer_group

    errors.add(:customer_group_id, :invalid)
  end
end
