class CustomerGroupForm < BaseForm
  attribute :name, :string
  attribute :terms, :string
  attribute :active, :boolean, default: true

  before_validation :normalize_fields

  validates :name, presence: true
  validate :name_must_not_be_duplicated
  validate :terms_must_have_letters_or_numbers

  attr_accessor :tenant
  attr_writer :customer_group

  delegate :id, :persisted?, to: :customer_group

  class << self
    def for_customer_group(customer_group)
      form = new(name: customer_group.name, terms: customer_group.terms.join("\n"), active: customer_group.activated?,
                 tenant: customer_group.tenant)
      form.customer_group = customer_group
      form
    end
  end

  def customer_group
    @customer_group ||= tenant.customer_groups.new
  end

  def term_list
    terms.to_s.lines.map(&:squish).compact_blank.uniq
  end

  def submit
    customer_group.update!(name:, terms: term_list, activated: active)
  end

  private

  def normalize_fields
    self.name = name.to_s.squish
  end

  def name_must_not_be_duplicated
    return if name.blank?

    query = tenant.customer_groups.where(name:)
    query = query.where.not(id: customer_group.id) if persisted?
    return unless query.exists?

    errors.add(:name, :taken)
  end

  def terms_must_have_letters_or_numbers
    return if term_list.all? { |term| CustomerGroup.compact(term).present? }

    errors.add(:terms, :without_letters_or_numbers)
  end
end
