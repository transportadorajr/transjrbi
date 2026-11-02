class ProductGroupForm < BaseForm
  attribute :name, :string
  attribute :parent_id, :integer
  attribute :product_names, default: -> { [] }
  attribute :active, :boolean, default: true

  before_validation :normalize_fields

  validates :name, presence: true
  validate :name_must_not_be_duplicated
  validate :parent_must_be_a_group
  validate :product_names_must_not_be_taken

  attr_accessor :tenant
  attr_writer :product_group

  delegate :id, :persisted?, to: :product_group

  class << self
    def for_product_group(product_group)
      form = new(name: product_group.name, parent_id: product_group.parent_id, product_names: product_group.product_names,
                 active: product_group.activated?, tenant: product_group.tenant)
      form.product_group = product_group
      form
    end
  end

  def product_group
    @product_group ||= tenant.product_groups.new
  end

  def parent
    return product_group.parent if persisted?
    return if parent_id.blank?
    return @parent if defined?(@parent)

    @parent = tenant.product_groups.groups.find_by(id: parent_id)
  end

  def subgroup?
    parent_id.present?
  end

  def available_product_names
    taken = taken_product_names

    document_product_names.reject { |product_name, _| taken.include?(ProductGroup.compact(product_name)) }
  end

  def submit
    transaction do
      product_group.update!(name:, parent:, product_names: subgroup? ? product_names : [], activated: active)
      ProductGroups::AssignCommand.call(tenant)
    end
  end

  private

  def normalize_fields
    self.name = name.to_s.squish
    self.parent_id = product_group.parent_id if persisted?
    self.product_names = Array(product_names).map(&:squish).compact_blank.uniq
  end

  def name_must_not_be_duplicated
    return if name.blank?

    query = tenant.product_groups.where(name:, parent_id:)
    query = query.where.not(id: product_group.id) if persisted?
    return unless query.exists?

    errors.add(:name, :taken)
  end

  def parent_must_be_a_group
    return if parent_id.blank? || parent

    errors.add(:parent_id, :invalid)
  end

  def product_names_must_not_be_taken
    taken = taken_product_names
    product_names_taken = product_names.select { |product_name| taken.include?(ProductGroup.compact(product_name)) }
    return if product_names_taken.empty?

    errors.add(:product_names, :taken, product_names: product_names_taken.to_sentence)
  end

  def taken_product_names
    other_subgroups = tenant.product_groups.nested
    other_subgroups = other_subgroups.where.not(id: product_group.id) if persisted?

    other_subgroups.flat_map(&:compacted_product_names).to_set
  end

  def document_product_names
    tenant.atua_transport_documents.active.where.not(product_name: nil).group(:product_name).count
      .sort_by { |product_name, count| [-count, product_name] }
  end
end
