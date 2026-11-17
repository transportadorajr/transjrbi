class AddActivatedAtToRegistrations < ActiveRecord::Migration[8.1]
  TABLES = %i[cities holidays macro_regions excluded_issuers route_distances resources].freeze

  def change
    TABLES.each do |table|
      add_column table, :activated_at, :datetime, default: -> { 'CURRENT_TIMESTAMP' }
    end
  end
end
