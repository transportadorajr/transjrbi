class AddActiveToRegistrations < ActiveRecord::Migration[8.1]
  TABLES = %i[cities holidays macro_regions excluded_issuers route_distances resources].freeze

  def change
    TABLES.each do |table|
      add_column table, :active, :boolean, default: true, null: false
    end
  end
end
