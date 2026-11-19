module MaintenanceOrderItemable
  extend ActiveSupport::Concern

  included do
    has_one :item, class_name: 'MaintenanceOrderItem', as: :itemizable, inverse_of: :itemizable
  end
end
