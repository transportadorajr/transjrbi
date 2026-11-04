class RouteDistanceForm < BaseForm
  STATE_FORMAT = /\A[A-Z]{2}\z/

  attribute :customer_code, :string
  attribute :origin_city, :string
  attribute :origin_state, :string
  attribute :destination_city, :string
  attribute :destination_state, :string
  attribute :distance_km, :string

  before_validation :normalize_fields

  validates :customer_code, :origin_city, :origin_state, :destination_city, :destination_state, :distance_km, presence: true
  validates :origin_state, :destination_state, format: { with: STATE_FORMAT }, allow_blank: true
  validate :customer_must_exist
  validate :distance_km_must_be_positive
  validate :route_must_be_unique

  attr_accessor :tenant, :batch_import
  attr_writer :route_distance
  attr_reader :documents_count

  delegate :id, :persisted?, to: :route_distance

  class << self
    def for_route_distance(route_distance)
      form = new(
        customer_code: route_distance.customer_code.to_s, origin_city: route_distance.origin_city, origin_state: route_distance.origin_state,
        destination_city: route_distance.destination_city, destination_state: route_distance.destination_state,
        distance_km: format_distance(route_distance.distance_km), tenant: route_distance.tenant
      )
      form.route_distance = route_distance
      form
    end

    def format_distance(distance_km)
      ActiveSupport::NumberHelper.number_to_rounded(distance_km, precision: 2, separator: ',', delimiter: '')
    end
  end

  def route_distance
    @route_distance ||= tenant.route_distances.new
  end

  def distance_km_value
    BigDecimal(distance_km.to_s.strip.delete('.').tr(',', '.')).round(2)
  rescue ArgumentError
    nil
  end

  def submit
    transaction do
      route_distance.update!(customer_code:, origin_city:, origin_state:, destination_city:, destination_state:,
                             distance_km: distance_km_value)
      next if batch_import

      RouteDistances::ApplyCommand.call(tenant)
      @documents_count = route_distance.transport_documents.count
    end
  end

  private

  def normalize_fields
    self.customer_code = customer_code.to_s.strip
    %i[origin_city origin_state destination_city destination_state].each do |field|
      public_send(:"#{field}=", RouteDistance.normalize_city(public_send(field)))
    end
    self.distance_km = distance_km.to_s.strip
  end

  def customer_must_exist
    return if customer_code.blank? || tenant.atua_customers.exists?(code: customer_code)

    errors.add(:customer_code, :inclusion)
  end

  def distance_km_must_be_positive
    return if distance_km.blank? || distance_km_value&.positive?

    errors.add(:distance_km, :greater_than, count: 0)
  end

  def route_must_be_unique
    return if errors.any?

    routes = tenant.route_distances.where(customer_code:, origin_city:, origin_state:, destination_city:, destination_state:)
    routes = routes.where.not(id: route_distance.id) if persisted?
    errors.add(:base, :taken_route) if routes.exists?
  end
end
