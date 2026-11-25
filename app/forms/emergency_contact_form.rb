class EmergencyContactForm < BaseForm
  attribute :name, :string
  attribute :relationship_type, :string
  attribute :phone, :string
  attribute :secondary_phone, :string
  attribute :position, :integer
  attribute :notes, :string

  before_validation :normalize_fields

  validates :name, :phone, presence: true
  validates :relationship_type, inclusion: { in: EmergencyContact.relationship_types.keys }, allow_blank: true
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validate :phones_must_have_valid_digits

  attr_accessor :employee
  attr_writer :emergency_contact

  delegate :id, :persisted?, to: :emergency_contact

  class << self
    def for_emergency_contact(emergency_contact)
      form = new(employee: emergency_contact.employee, name: emergency_contact.name, relationship_type: emergency_contact.relationship_type,
                 phone: emergency_contact.phone, secondary_phone: emergency_contact.secondary_phone, position: emergency_contact.position,
                 notes: emergency_contact.notes)
      form.emergency_contact = emergency_contact
      form
    end

    def for_employee(employee)
      new(employee:, position: employee.emergency_contacts.maximum(:position).to_i + 1)
    end
  end

  def emergency_contact
    @emergency_contact ||= employee.emergency_contacts.new(tenant: employee.tenant)
  end

  def submit
    emergency_contact.update!(name:, relationship_type:, phone:, secondary_phone:, position:, notes:)
  end

  private

  def normalize_fields
    self.name = name&.squish
    self.relationship_type = relationship_type.presence
    self.phone = EmergencyContact.normalize_phone(phone)
    self.secondary_phone = EmergencyContact.normalize_phone(secondary_phone)
    self.notes = notes.to_s.squish.presence
  end

  def phones_must_have_valid_digits
    %i[phone secondary_phone].each do |attribute|
      value = public_send(attribute)
      errors.add(attribute, :invalid) if value.present? && !EmergencyContact.valid_phone?(value)
    end
  end
end
