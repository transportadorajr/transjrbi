class MaintenanceOrderPostingForm < BaseForm
  PERMITTED_ATTRIBUTES = %i[atua_order_number posted_on posting_verified].freeze

  attribute :atua_order_number, :string
  attribute :posted_on, :date
  attribute :posting_verified, :boolean, default: false

  before_validation :normalize_fields

  validates :atua_order_number, :posted_on, presence: true
  validate :order_must_be_finished
  validate :posted_on_must_not_precede_conclusion
  validate :posted_on_must_not_be_in_the_future
  validate :atua_order_number_must_be_unique

  attr_accessor :maintenance_order, :posted_by

  class << self
    def for_maintenance_order(maintenance_order)
      new(maintenance_order:, atua_order_number: maintenance_order.atua_order_number,
          posted_on: maintenance_order.posted_on || Time.zone.today, posting_verified: maintenance_order.posting_verified)
    end
  end

  def persisted?
    true
  end

  def submit
    maintenance_order.posted_by = posted_by if maintenance_order.posted_by.nil? || maintenance_order.atua_order_number != atua_order_number
    maintenance_order.update!(atua_order_number:, posted_on:, posting_verified:)
  end

  private

  def normalize_fields
    self.atua_order_number = atua_order_number.to_s.strip.presence
  end

  def order_must_be_finished
    return if maintenance_order.finished?

    errors.add(:base, :not_finished, status: maintenance_order.status_type_name.downcase)
  end

  def posted_on_must_not_precede_conclusion
    return if posted_on.blank? || maintenance_order.finished_at.blank?
    return if posted_on >= maintenance_order.finished_at.to_date

    errors.add(:posted_on, :before_conclusion)
  end

  def posted_on_must_not_be_in_the_future
    errors.add(:posted_on, :future) if posted_on.present? && posted_on > Time.zone.today
  end

  def atua_order_number_must_be_unique
    return if atua_order_number.blank?

    taken = maintenance_order.tenant.maintenance_orders.where(atua_order_number:).where.not(id: maintenance_order.id).pick(:number)
    errors.add(:atua_order_number, :taken, number: taken) if taken
  end
end
