class TransportDocumentDistanceForm < BaseForm
  attribute :distance_km, :string

  before_validation :normalize_distance_km

  validate :distance_km_must_be_positive

  attr_accessor :transport_document

  delegate :id, to: :transport_document

  class << self
    def for_transport_document(transport_document)
      distance_km = transport_document.distance_edited_at ? RouteDistanceForm.format_distance(transport_document.distance_km) : nil

      new(transport_document:, distance_km:)
    end
  end

  def persisted?
    true
  end

  def to_param
    id.to_s
  end

  def distance_km_value
    return if distance_km.blank?

    BigDecimal(distance_km.delete('.').tr(',', '.')).round(2)
  rescue ArgumentError
    nil
  end

  def submit
    TransportDocuments::UpdateDistanceCommand.call(transport_document, distance_km_value)
  end

  private

  def normalize_distance_km
    self.distance_km = distance_km.to_s.strip
  end

  def distance_km_must_be_positive
    return if distance_km.blank? || distance_km_value&.positive?

    errors.add(:distance_km, :greater_than, count: 0)
  end
end
