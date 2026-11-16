class RevenueGoalsForm < BaseForm
  SECTIONS = RevenueGoal::Targets::SECTIONS

  class Line
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :key, :string
    attribute :name, :string
    attribute :amount, :string
    attribute :reference_cents, :integer

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

  validate :month_must_be_a_month
  validate :company_must_be_positive
  validate :lines_must_be_positive
  validate :lines_must_be_listed

  class << self
    def for_month(tenant, month)
      targets = RevenueGoal::Targets.new(tenant, month)
      company = targets.goals.find(&:company?)

      form = new(tenant:, month: month.strftime(RevenueGoal::MONTH_FORMAT), company: format_cents(company&.amount_cents))
      SECTIONS.each_key { |section| form.assign_lines(section, listed_lines(targets, section)) }
      form
    end

    private

    def listed_lines(targets, section)
      amounts = targets.goal_amounts(section)
      references = targets.reference_cents(section)

      targets.options(section).map do |key, name|
        Line.new(key:, name:, amount: format_cents(amounts[key]), reference_cents: references.fetch(key, 0))
      end
    end
  end

  SECTIONS.each_key do |section|
    define_method(section) { lines[section] }

    define_method(:"#{section}_attributes=") do |attributes|
      assign_lines(section, attributes.to_h.values.map { |line| posted_line(section, line) })
    end
  end

  def assign_lines(section, section_lines)
    lines[section] = section_lines
  end

  def lines
    @lines ||= SECTIONS.keys.index_with { [] }
  end

  def total_cents(section)
    lines[section].filter_map(&:amount_cents).sum
  end

  def month_value
    RevenueGoal.parse_month(month) if month.to_s.match?(/\A\d{4}-\d{2}\z/)
  end

  def company_cents
    self.class.parse_cents(company)
  end

  def submit
    transaction do
      save_goal({ target_type: 'company' }, company, company_cents)
      lines.each do |section, section_lines|
        target_type = SECTIONS.fetch(section)
        column = RevenueGoal::TARGET_COLUMNS.fetch(target_type)
        section_lines.each { |line| save_goal({ target_type:, column => line.key }, line.amount, line.amount_cents) }
      end
    end
  end

  private

  def targets
    @targets ||= RevenueGoal::Targets.new(tenant, month_value)
  end

  def posted_line(section, line)
    key = line[:key].to_s.strip
    key = key.upcase if section == :vehicles
    name = targets.options(section)[key] if month_value

    Line.new(key:, name: name || key, amount: line[:amount])
  end

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

  def lines_must_be_positive
    lines.each do |section, section_lines|
      section_lines.reject { |line| line.amount.blank? || line.amount_cents&.positive? }.each do |line|
        errors.add(:base, :"invalid_#{section}_amount", name: line.name)
      end
    end
  end

  def lines_must_be_listed
    return unless month_value

    lines.each do |section, section_lines|
      allowed = targets.options(section)
      section_lines.reject { |line| allowed.key?(line.key) }.each { |line| errors.add(:base, :"unknown_#{section}", name: line.name) }
    end
  end
end
