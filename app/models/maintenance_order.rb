class MaintenanceOrder < ApplicationRecord
  include AASM
  include Sortable

  FEATURE = :maintenance
  NUMBER_LOCK_NAMESPACE = 'maintenance_orders.number'.freeze
  EQUIPMENTS = %i[truck_tractor trailer b_train road_train rigid_truck light_vehicle other].freeze
  MAINTENANCES = %i[preventive corrective roadside inspection improvement].freeze
  PRIORITIES = %i[high medium low].freeze
  EXECUTION_PLACES = %i[internal_workshop third_party on_route].freeze
  AFFECTED_SYSTEMS = %i[engine cooling fuel clutch transmission axles brakes suspension steering tires electrical
                        pneumatic cab_body implement lubrication other].freeze
  RELEASE_TESTS = %i[road_test yard_test not_applicable].freeze
  STATUSES = %i[open in_progress waiting_parts finished cancelled].freeze
  PENDING_STATUSES = %i[open in_progress waiting_parts].freeze
  STATUS_BADGES = { open: :primary, in_progress: :warning, waiting_parts: :secondary, finished: :success,
                    cancelled: :danger }.freeze

  sortable :number, -> { arel_table[:number] }
  sortable :plate
  sortable :opened_at, -> { arel_table[:opened_at] }

  belongs_to :tenant
  belongs_to :supervisor, class_name: 'WorkshopEmployee', optional: true
  belongs_to :opened_by, class_name: 'User', optional: true
  has_many :parts, class_name: 'MaintenanceOrderPart', dependent: :delete_all
  has_many :labors, class_name: 'MaintenanceOrderLabor', dependent: :delete_all
  has_many :services, class_name: 'MaintenanceOrderService', dependent: :delete_all

  enum :equipment_type, EQUIPMENTS.index_with(&:to_s), validate: true, prefix: true
  enum :maintenance_type, MAINTENANCES.index_with(&:to_s), validate: true, prefix: true
  enum :priority_type, PRIORITIES.index_with(&:to_s), validate: true, prefix: true
  enum :execution_place_type, EXECUTION_PLACES.index_with(&:to_s), validate: true, prefix: true
  enum :affected_system_type, AFFECTED_SYSTEMS.index_with(&:to_s), validate: true, prefix: true
  enum :release_test_type, RELEASE_TESTS.index_with(&:to_s), validate: { allow_nil: true }, prefix: true
  enum :status_type, STATUSES.index_with(&:to_s), validate: true

  monetize :parts_total_cents, :services_total_cents, :total_cents

  validates :number, :plate, :opened_at, :reported_defect, presence: true
  validates :number, uniqueness: { scope: :tenant_id }

  scope :by_number, ->(number) { where(number: number.to_i) }
  scope :by_plate, ->(plate) { where(arel_table[:plate].matches("%#{sanitize_sql_like(plate.to_s.delete('^A-Za-z0-9'))}%")) }
  scope :by_status_type, ->(status_type) { where(status_type:) }
  scope :by_maintenance_type, ->(maintenance_type) { where(maintenance_type:) }
  scope :by_priority_type, ->(priority_type) { where(priority_type:) }
  scope :by_affected_system_type, ->(affected_system_type) { where(affected_system_type:) }
  scope :by_opened_from, ->(date) { parse_date(date)&.then { |day| where(opened_at: day.beginning_of_day..) } || all }
  scope :by_opened_until, ->(date) { parse_date(date)&.then { |day| where(opened_at: ..day.end_of_day) } || all }
  scope :pending, -> { where(status_type: PENDING_STATUSES.map(&:to_s)) }
  scope :stopped, -> { pending.where(vehicle_stopped: true) }

  aasm column: :status_type, enum: true, create_scopes: false, whiny_persistence: true do
    state :open, initial: true
    state :in_progress, :waiting_parts, :finished, :cancelled

    event :start do
      transitions from: %i[open waiting_parts], to: :in_progress
    end

    event :wait_parts do
      transitions from: %i[open in_progress], to: :waiting_parts
    end

    event :finish do
      transitions from: PENDING_STATUSES, to: :finished
    end

    event :cancel do
      transitions from: PENDING_STATUSES, to: :cancelled
    end
  end

  class << self
    def enabled?(tenant)
      Flipper.enabled?(FEATURE, tenant)
    end

    def next_number(tenant)
      connection.execute(sanitize_sql_array(['SELECT pg_advisory_xact_lock(hashtext(?), ?)', NUMBER_LOCK_NAMESPACE, tenant.id]))

      tenant.maintenance_orders.maximum(:number).to_i + 1
    end

    def parse_date(value)
      Date.iso8601(value.to_s)
    rescue Date::Error
      nil
    end
  end

  def status_badge_kind
    STATUS_BADGES.fetch(status_type.to_sym)
  end

  def editable?
    PENDING_STATUSES.include?(status_type.to_sym)
  end

  def validate_start
    return transition_not_allowed unless may_start?

    start!
  end

  def validate_wait_parts
    return transition_not_allowed unless may_wait_parts?

    wait_parts!
  end

  def validate_cancel
    return transition_not_allowed unless may_cancel?

    cancel!
  end

  private

  def transition_not_allowed
    errors.add(:base, :transition_not_allowed, status: status_type_name.downcase)
    nil
  end
end

# == Schema Information
#
# Table name: maintenance_orders
#
#  id                   :bigint           not null, primary key
#  affected_system_type :enum             not null
#  diagnosis            :text
#  driver_code          :bigint
#  driver_name          :string
#  equipment_other      :string
#  equipment_type       :enum             not null
#  execution_place_type :enum             default("internal_workshop"), not null
#  finished_at          :datetime
#  hour_meter           :decimal(10, 1)
#  maintenance_type     :enum             not null
#  next_preventive_km   :integer
#  number               :bigint           not null
#  odometer_km          :integer
#  opened_at            :datetime         not null
#  parts_total_cents    :bigint           default(0), not null
#  performed_service    :text
#  plate                :string           not null
#  priority_type        :enum             default("medium"), not null
#  release_test_type    :enum
#  reported_defect      :text             not null
#  services_total_cents :bigint           default(0), not null
#  status_type          :enum             default("open"), not null
#  total_cents          :bigint           default(0), not null
#  vehicle_stopped      :boolean          default(FALSE), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  opened_by_id         :bigint
#  supervisor_id        :bigint
#  tenant_id            :bigint           not null
#
# Indexes
#
#  index_maintenance_orders_on_opened_by_id               (opened_by_id)
#  index_maintenance_orders_on_supervisor_id              (supervisor_id)
#  index_maintenance_orders_on_tenant_id                  (tenant_id)
#  index_maintenance_orders_on_tenant_id_and_number       (tenant_id,number) UNIQUE
#  index_maintenance_orders_on_tenant_id_and_plate        (tenant_id,plate)
#  index_maintenance_orders_on_tenant_id_and_status_type  (tenant_id,status_type)
#
# Foreign Keys
#
#  fk_rails_...  (opened_by_id => users.id)
#  fk_rails_...  (supervisor_id => workshop_employees.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
