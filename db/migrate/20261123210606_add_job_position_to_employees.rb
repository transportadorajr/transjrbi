class AddJobPositionToEmployees < ActiveRecord::Migration[8.1]
  def change
    add_reference :employees, :job_position, foreign_key: true
  end
end
