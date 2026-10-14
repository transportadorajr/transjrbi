module Atua
  module Importable
    extend ActiveSupport::Concern

    PLATE_SEPARATORS = /[\s-]/

    included do
      belongs_to :tenant
      belongs_to :import, class_name: 'Atua::Import', foreign_key: :atua_import_id, optional: true, inverse_of: false

      validates :imported_at, presence: true

      scope :active, -> { where(removed_from_atua_at: nil) }
      scope :removed_from_atua, -> { where.not(removed_from_atua_at: nil) }
    end

    class_methods do
      def normalize_plate(plate)
        plate.to_s.upcase.gsub(PLATE_SEPARATORS, '')
      end

      def date_range(start_date, end_date)
        (start_date.presence&.to_date)..(end_date.presence&.to_date)
      end

      def time_range(start_date, end_date)
        range = date_range(start_date, end_date)

        (range.begin&.in_time_zone&.beginning_of_day)..(range.end&.in_time_zone&.end_of_day)
      end
    end

    def active?
      removed_from_atua_at.nil?
    end
  end
end
