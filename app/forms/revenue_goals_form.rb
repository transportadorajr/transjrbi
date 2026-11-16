class RevenueGoalsForm < BaseForm
  class VehicleLine
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :plate, :string
    attribute :amount, :string

    def persisted?
      false
    end

    def amount_cents
      RevenueGoalsForm.parse_cents(amount)
    end
  end

  class CustomerGroupLine
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :customer_group_id, :integer
    attribute :name, :string
    attribute :amount, :string

    def persisted?
      false
    end

    def amount_cents
      RevenueGoalsForm.parse_cents(amount)
    end
  end

  attribute :month, :string
  attribute :company, :string

  attr_accessor :tenant
  attr_writer :vehicles, :customer_groups

  validate :month_must_be_a_month
  validate :company_must_be_positive
  validate :vehicles_must_be_positive
  validate :vehicles_must_be_listed
  validate :customer_groups_must_be_positive
  validate :customer_groups_must_be_listed

  class << self
    def for_month(tenant, month)
      goals = tenant.revenue_goals.for_month(month).to_a
      company = goals.find(&:company?)
      vehicles = goals.select(&:vehicle?).to_h { |goal| [goal.plate, goal.amount_cents] }

      form = new(tenant:, month: month.strftime(RevenueGoal::MONTH_FORMAT), company: format_cents(company&.amount_cents))
      form.vehicles = (fleet_plates(tenant) | vehicles.keys).sort.map { |plate| VehicleLine.new(plate:, amount: format_cents(vehicles[plate])) }
      form.customer_groups = customer_group_lines(tenant, goals.select(&:customer_group?))
      form
    end

    def customer_group_lines(tenant, goals)
      amounts = goals.to_h { |goal| [goal.customer_group_id, goal.amount_cents] }

      RevenueGoal.listed_customer_groups(tenant, amounts.keys).map do |group|
        CustomerGroupLine.new(customer_group_id: group.id, name: group.name, amount: format_cents(amounts[group.id]))
      end
    end

    def fleet_plates(tenant)
      tenant.own_fleet&.plates.to_a
    end
  end

  def vehicles
    @vehicles ||= []
  end

  def vehicles_attributes=(attributes)
    self.vehicles = attributes.to_h.values.map { |line| VehicleLine.new(plate: line[:plate].to_s.strip.upcase, amount: line[:amount]) }
  end

  def customer_groups
    @customer_groups ||= []
  end

  def customer_groups_attributes=(attributes)
    names = tenant.customer_groups.pluck(:id, :name).to_h

    self.customer_groups = attributes.to_h.values.map do |line|
      id = line[:customer_group_id].to_i
      CustomerGroupLine.new(customer_group_id: id, name: names[id], amount: line[:amount])
    end
  end

  def month_value
    RevenueGoal.parse_month(month) if month.to_s.match?(/\A\d{4}-\d{2}\z/)
  end

  def company_cents
    self.class.parse_cents(company)
  end

  def vehicles_total_cents
    vehicles.filter_map(&:amount_cents).sum
  end

  def customer_groups_total_cents
    customer_groups.filter_map(&:amount_cents).sum
  end

  def submit
    transaction do
      save_goal({ target_type: 'company' }, company, company_cents)
      vehicles.each { |line| save_goal({ target_type: 'vehicle', plate: line.plate }, line.amount, line.amount_cents) }
      customer_groups.each do |line|
        save_goal({ target_type: 'customer_group', customer_group_id: line.customer_group_id }, line.amount, line.amount_cents)
      end
    end
  end

  private

  def save_goal(target, amount, cents)
    goal = tenant.revenue_goals.for_month(month_value).find_or_initialize_by(target)
    return goal.destroy! if amount.blank?

    goal.update!(amount_cents: cents)
  end

  def month_must_be_a_month
    errors.add(:month, :invalid) unless month_value
  end

  def company_must_be_positive
    return if company.blank? || company_cents&.positive?

    errors.add(:company, :greater_than, count: 0)
  end

  def vehicles_must_be_positive
    vehicles.reject { |line| line.amount.blank? || line.amount_cents&.positive? }.each do |line|
      errors.add(:base, :invalid_vehicle_amount, plate: line.plate)
    end
  end

  def vehicles_must_be_listed
    return unless month_value

    allowed = self.class.fleet_plates(tenant) | tenant.revenue_goals.for_month(month_value).vehicle.pluck(:plate)
    vehicles.reject { |line| allowed.include?(line.plate) }.each { |line| errors.add(:base, :unknown_vehicle, plate: line.plate) }
  end

  def customer_groups_must_be_positive
    customer_groups.reject { |line| line.amount.blank? || line.amount_cents&.positive? }.each do |line|
      errors.add(:base, :invalid_customer_group_amount, name: line.name || line.customer_group_id)
    end
  end

  def customer_groups_must_be_listed
    return unless month_value

    goal_group_ids = tenant.revenue_goals.for_month(month_value).customer_group.pluck(:customer_group_id)
    allowed = RevenueGoal.listed_customer_groups(tenant, goal_group_ids).ids
    customer_groups.reject { |line| allowed.include?(line.customer_group_id) }.each do |line|
      errors.add(:base, :unknown_customer_group, id: line.customer_group_id)
    end
  end
end
