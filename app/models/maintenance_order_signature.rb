class MaintenanceOrderSignature < ApplicationRecord
  FEATURE = :maintenance_order_signatures
  SIGNER_ROLES = %i[supervisor mechanic].freeze
  ASPECT_RATIO = 3
  VIEWBOX_WIDTH = 300
  VIEWBOX_HEIGHT = VIEWBOX_WIDTH / ASPECT_RATIO
  MIN_POINTS = 10
  MAX_POINTS = 5_000
  MAX_STROKES = 100
  PRECISION = 3

  belongs_to :tenant
  belongs_to :maintenance_order
  belongs_to :workshop_employee
  belongs_to :signed_by, class_name: 'User', optional: true

  enum :signer_role_type, SIGNER_ROLES.index_with(&:to_s), validate: true

  validates :signer_name, :signed_at, :content_digest, presence: true
  validates :workshop_employee_id, uniqueness: { scope: %i[maintenance_order_id signer_role_type] }, if: :known_role?
  validate :strokes_must_be_drawn

  class << self
    def enabled?(tenant)
      Flipper.enabled?(FEATURE, tenant)
    end

    def parse_strokes(value)
      strokes = JSON.parse(value.to_s)
      return [] unless strokes.is_a?(Array) && strokes.size <= MAX_STROKES

      strokes.filter_map { |stroke| parse_stroke(stroke) }
    rescue JSON::ParserError
      []
    end

    def drawn?(strokes)
      points = strokes.sum(&:size)

      points.between?(MIN_POINTS, MAX_POINTS)
    end

    private

    def parse_stroke(stroke)
      return unless stroke.is_a?(Array)

      points = stroke.map { |point| parse_point(point) }
      return if points.empty? || points.any?(&:nil?)

      points
    end

    def parse_point(point)
      return unless point.is_a?(Array) && point.size == 2 && point.all?(Numeric)
      return unless point.all? { |coordinate| coordinate.between?(0, 1) }

      point.map { |coordinate| coordinate.to_f.round(PRECISION) }
    end
  end

  def to_svg
    paths = strokes.map { |stroke| svg_path(stroke) }

    "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 #{VIEWBOX_WIDTH} #{VIEWBOX_HEIGHT}\">" \
      '<g fill="none" stroke="#111111" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' \
      "#{paths.join}</g></svg>"
  end

  private

  def svg_path(stroke)
    points = stroke.map { |x, y| "#{svg_coordinate(x * VIEWBOX_WIDTH)} #{svg_coordinate(y * VIEWBOX_HEIGHT)}" }
    points << points.first if points.one?

    "<path d=\"M #{points.join(' L ')}\"/>"
  end

  def svg_coordinate(value)
    format('%.1f', value)
  end

  def known_role?
    self.class.signer_role_types.key?(signer_role_type)
  end

  def strokes_must_be_drawn
    return if strokes.is_a?(Array) && self.class.drawn?(strokes)

    errors.add(:strokes, :blank)
  end
end

# == Schema Information
#
# Table name: maintenance_order_signatures
#
#  id                   :bigint           not null, primary key
#  content_digest       :string           not null
#  ip_address           :string
#  signed_at            :datetime         not null
#  signer_name          :string           not null
#  signer_role_type     :enum             not null
#  strokes              :jsonb            not null
#  user_agent           :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  maintenance_order_id :bigint           not null
#  signed_by_id         :bigint
#  tenant_id            :bigint           not null
#  workshop_employee_id :bigint           not null
#
# Indexes
#
#  index_maintenance_order_signatures_on_maintenance_order_id  (maintenance_order_id)
#  index_maintenance_order_signatures_on_signed_by_id          (signed_by_id)
#  index_maintenance_order_signatures_on_tenant_id             (tenant_id)
#  index_maintenance_order_signatures_on_workshop_employee_id  (workshop_employee_id)
#  index_maintenance_order_signatures_uniqueness               (maintenance_order_id,signer_role_type,workshop_employee_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (maintenance_order_id => maintenance_orders.id)
#  fk_rails_...  (signed_by_id => users.id)
#  fk_rails_...  (tenant_id => tenants.id)
#  fk_rails_...  (workshop_employee_id => workshop_employees.id)
#
