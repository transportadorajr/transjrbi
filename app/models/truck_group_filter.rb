class TruckGroupFilter
  EXCEPT_PREFIX = 'except-'.freeze
  VALUE_FORMAT = /\A(?:except-)?\d+\z/

  class << self
    def except_value(truck_group)
      "#{EXCEPT_PREFIX}#{truck_group.id}"
    end

    def except_name(truck_group)
      I18n.t('truck_groups.filter.except', name: truck_group.name)
    end
  end

  def initialize(truck_groups, value)
    @truck_groups = truck_groups
    @value = value.to_s
  end

  def apply(relation)
    return relation if value.blank?
    return relation.none unless truck_group

    grouped_plates = truck_groups.flat_map(&:plates)
    except? ? relation.without_truck_group(truck_group, grouped_plates) : relation.by_truck_group(truck_group, grouped_plates)
  end

  def name
    return unless truck_group

    except? ? self.class.except_name(truck_group) : truck_group.name
  end

  private

  attr_reader :truck_groups, :value

  def except?
    value.start_with?(EXCEPT_PREFIX)
  end

  def truck_group
    return @truck_group if defined?(@truck_group)

    @truck_group = truck_groups.find_by(id: value.delete_prefix(EXCEPT_PREFIX))
  end
end
