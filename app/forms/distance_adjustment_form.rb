class DistanceAdjustmentForm < BaseForm
  attribute :transport_document_number, :string
  attribute :distance_km, :string

  before_validation :normalize_fields

  validates :transport_document_number, :distance_km, presence: true
  validates :transport_document_number, format: { with: /\A\d+\z/ }, allow_blank: true
  validate :distance_km_must_be_positive
  validate :transport_document_number_must_be_unique

  attr_accessor :tenant
  attr_writer :distance_adjustment
  attr_reader :documents_count

  delegate :id, :persisted?, to: :distance_adjustment

  class << self
    def for_distance_adjustment(distance_adjustment)
      form = new(
        transport_document_number: distance_adjustment.transport_document_number,
        distance_km: format_distance(distance_adjustment.distance_km), tenant: distance_adjustment.tenant
      )
      form.distance_adjustment = distance_adjustment
      form
    end

    def format_distance(distance_km)
      ActiveSupport::NumberHelper.number_to_rounded(distance_km, precision: 2, separator: ',', delimiter: '')
    end
  end

  def distance_adjustment
    @distance_adjustment ||= tenant.distance_adjustments.new
  end

  def distance_km_value
    BigDecimal(distance_km.to_s.strip.delete('.').tr(',', '.')).round(2)
  rescue ArgumentError
    nil
  end

  def submit
    transaction do
      revert_previous_number
      distance_adjustment.update!(transport_document_number:, distance_km: distance_km_value)
      @documents_count = DistanceAdjustments::ApplyCommand.call(distance_adjustment)
    end
  end

  private

  def normalize_fields
    self.transport_document_number = DistanceAdjustment.normalize_number(transport_document_number)
    self.distance_km = distance_km.to_s.strip
  end

  def revert_previous_number
    previous_number = distance_adjustment.transport_document_number
    return if previous_number.nil? || previous_number == transport_document_number

    DistanceAdjustments::RevertCommand.call(tenant, previous_number)
    distance_adjustment.applied_at = nil
  end

  def distance_km_must_be_positive
    return if distance_km.blank? || distance_km_value&.positive?

    errors.add(:distance_km, :greater_than, count: 0)
  end

  def transport_document_number_must_be_unique
    return if transport_document_number.blank?

    adjustments = tenant.distance_adjustments.where(transport_document_number:)
    adjustments = adjustments.where.not(id: distance_adjustment.id) if persisted?
    errors.add(:transport_document_number, :taken) if adjustments.exists?
  end
end
