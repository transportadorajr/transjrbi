class CreateResources < ActiveRecord::Migration[8.1]
  def change
    create_table :resources do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.boolean :writable, null: false, default: true

      t.timestamps
    end

    add_index :resources, :slug, unique: true
  end
end
