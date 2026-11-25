class CreateEmergencyContacts < ActiveRecord::Migration[8.1]
  def change
    create_enum :emergency_contact_relationship_type, %w[spouse partner fiance mother father child sibling godparent other]

    create_table :emergency_contacts do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.string :name, null: false
      t.enum :relationship_type, enum_type: :emergency_contact_relationship_type
      t.string :phone
      t.string :secondary_phone
      t.text :notes
      t.integer :position, null: false, default: 1

      t.timestamps
    end
  end
end
