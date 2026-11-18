class CustomerCountryForm < BaseForm
  attribute :country_type, :string

  validates :country_type, inclusion: { in: Atua::Customer.country_types.keys }, allow_blank: true

  attr_accessor :customer

  delegate :id, to: :customer

  class << self
    def for_customer(customer)
      new(customer:, country_type: customer.country_edited_at ? customer.country_type : nil)
    end
  end

  def persisted?
    true
  end

  def to_param
    id.to_s
  end

  def submit
    Customers::UpdateCountryCommand.call(customer, country_type)
  end
end
