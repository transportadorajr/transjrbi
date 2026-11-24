class RevenueGoal
  class Targets
    SECTIONS = { vehicles: 'vehicle', truck_groups: 'truck_group', trailers: 'trailer', customer_groups: 'customer_group', regions: 'region' }.freeze

    def initialize(tenant, month)
      @tenant = tenant
      @month = month.beginning_of_month
    end

    attr_reader :month

    def goals
      @goals ||= tenant.revenue_goals.for_month(month).to_a
    end

    def options(section)
      @options ||= {}
      @options[section] ||= send(:"#{section}_options")
    end

    def reference_cents(section)
      @reference_cents ||= {}
      @reference_cents[section] ||= billing(section, billed(month.prev_month.all_month))
    end

    def billing(section, relation)
      send(:"#{section}_billing", relation).transform_keys(&:to_s)
    end

    def goal_amounts(section)
      goals.select { |goal| goal.target_type == SECTIONS.fetch(section) }.to_h { |goal| [goal.target_value.to_s, goal.amount_cents] }
    end

    def truck_group_plates
      @truck_group_plates ||= plates_by_truck_group(tractor_plates, :plate)
    end

    def truck_group_trailer_plates
      @truck_group_trailer_plates ||= plates_by_truck_group(fleet_trailer_plates, :trailer_plate)
    end

    private

    attr_reader :tenant

    def billed(period)
      tenant.billable_freights.active.not_canceled.where(issued_at: period.first.beginning_of_day..period.last.end_of_day)
    end

    def goal_values(section)
      goal_amounts(section).keys
    end

    def vehicles_options
      (tractor_plates | goal_values(:vehicles)).sort.index_with(&:itself)
    end

    def tractor_plates
      @tractor_plates ||= fleet_plates - fleet_trailer_plates
    end

    def plates_by_truck_group(plates, column)
      axles = latest_axles(plates, column)

      plates.group_by { |plate| truck_group_for(active_truck_groups, plate, axles[plate])&.id&.to_s }.except(nil)
    end

    def active_truck_groups
      @active_truck_groups ||= tenant.truck_groups.activated.to_a
    end

    def latest_axles(plates, column)
      documents = tenant.billable_freights.active.not_canceled.where(column => plates).where.not(axles: nil)
      latest = documents.where(issued_at: ..month.end_of_month.end_of_day).reorder(column, issued_at: :desc).pluck(column, :axles)
        .each_with_object({}) { |(plate, axles), found| found[plate] ||= axles }

      latest.merge(predominant_axles(documents.where(issued_at: month.beginning_of_day..month.end_of_month.end_of_day), column))
    end

    def predominant_axles(documents, column)
      documents.reorder(issued_at: :desc).pluck(column, :axles).group_by(&:first).transform_values do |rows|
        rows.map(&:last).tally.max_by { |_axles, trips| trips }.first
      end
    end

    def truck_group_for(truck_groups, plate, axles)
      return truck_groups.find { |truck_group| truck_group.plates.include?(plate) } if axles.nil?

      TruckGroup.for_document(truck_groups, plate:, axles:)
    end

    def truck_groups_options
      truck_groups = tenant.truck_groups
      truck_groups.where(id: goal_values(:truck_groups)).or(truck_groups.activated).order(:name, :id).to_h { |group| [group.id.to_s, group.name] }
    end

    def trailers_options
      (fleet_trailer_plates | goal_values(:trailers)).sort.index_with(&:itself)
    end

    def fleet_plates
      @fleet_plates ||= tenant.own_fleet&.plates.to_a
    end

    def fleet_trailer_plates
      @fleet_trailer_plates ||= tenant.atua_vehicles.trailers.where(plate: fleet_plates).distinct.pluck(:plate)
    end

    def customer_groups_options
      RevenueGoal.listed_customer_groups(tenant, goal_values(:customer_groups)).to_h { |group| [group.id.to_s, group.name] }
    end

    def regions_options
      regions = tenant.macro_regions
      regions.where(id: goal_values(:regions)).or(regions.activated).order(:name, :id).to_h { |region| [region.id.to_s, region.name] }
    end

    def vehicles_billing(relation)
      relation.group(:plate).sum(:freight_cents)
    end

    def truck_groups_billing(relation)
      billed = vehicles_billing(relation.where(plate: truck_group_plates.values.flatten))

      truck_group_plates.transform_values { |plates| (plates.sum { |plate| billed.fetch(plate, 0) }.to_d / plates.size).round.to_i }
    end

    def trailers_billing(relation)
      relation.group(:trailer_plate).sum(:freight_cents)
    end

    def customer_groups_billing(relation)
      relation.left_joins(:taker).group(Atua::Customer.arel_table[:customer_group_id]).sum(:freight_cents)
    end

    def regions_billing(relation)
      relation.group(:origin_macro_region_id).sum(:freight_cents)
    end
  end
end
