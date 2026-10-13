class ResourceForm < BaseForm
  attribute :name, :string
  attribute :slug, :string
  attribute :writable, :boolean, default: true

  validates :name, :slug, presence: true
  validates :slug, format: { with: Resource::SLUG_FORMAT }, allow_blank: true
  validate :slug_must_not_be_duplicated

  attr_writer :resource

  delegate :id, :persisted?, to: :resource

  class << self
    def for_resource(resource)
      form = new(name: resource.name, slug: resource.slug, writable: resource.writable)
      form.resource = resource
      form
    end
  end

  def resource
    @resource ||= Resource.new
  end

  def submit
    resource.update!(name:, slug:, writable:)
  end

  private

  def slug_must_not_be_duplicated
    return if slug.blank?

    query = Resource.where(slug:)
    query = query.where.not(id: resource.id) if persisted?
    return unless query.exists?

    errors.add(:slug, :taken)
  end
end
