module MaintenanceCatalogItem
  extend ActiveSupport::Concern

  STATUSES = %w[active inactive].freeze

  included do
    sortable :code
    sortable :description

    belongs_to :tenant

    validates :description, presence: true, uniqueness: { scope: :tenant_id }
    validates :code, uniqueness: { scope: :tenant_id }, allow_nil: true

    scope :active, -> { where(active: true) }
    scope :by_term, ->(term) { where(arel_table[:description].matches("%#{sanitize_sql_like(term)}%")).or(where(arel_table[:code].matches("%#{sanitize_sql_like(term)}%"))) }
    scope :by_status, ->(status) { STATUSES.include?(status.to_s) ? where(active: status.to_s == 'active') : all }
  end

  class_methods do
    def statuses
      STATUSES.index_by { |status| I18n.t("maintenance_catalog.status.#{status}") }
    end
  end

  def label
    [code, description].compact.join(' - ')
  end
end
