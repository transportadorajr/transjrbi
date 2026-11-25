module EmergencyContacts
  class SeedCommand
    PATH = 'config/emergency_contacts.json.enc'.freeze
    TRUNCATED_NAME_LENGTH = 30
    CONTACT_ATTRIBUTES = %w[name relationship_type phone secondary_phone notes].freeze

    class << self
      def call(tenant, file: Rails.application.encrypted(PATH))
        new(tenant, file).call
      end
    end

    def initialize(tenant, file)
      @tenant = tenant
      @file = file
    end

    def call
      return unless readable?

      data.fetch('emergency_contacts').each { |attributes| seed_employee_contacts(attributes) }
    end

    private

    attr_reader :tenant, :file

    def readable?
      return file.exist? unless file.is_a?(ActiveSupport::EncryptedFile)

      file.key.present? && file.content_path.exist?
    end

    def data
      @data ||= JSON.parse(file.read)
    end

    def seed_employee_contacts(attributes)
      employee = find_employee(attributes)
      return if employee.nil? || employee.emergency_contacts.exists?

      EmergencyContact.transaction do
        attributes.fetch('contacts').each.with_index(1) do |contact, position|
          employee.emergency_contacts.create!(tenant:, position:, **contact.slice(*CONTACT_ATTRIBUTES).symbolize_keys)
        end
      end
    end

    def find_employee(attributes)
      by_registration(attributes) || by_name(attributes.fetch('employee'))
    end

    def by_registration(attributes)
      return if attributes['registration'].blank?

      tenant.employees.find_by(attributes.slice('company_type', 'registration'))
    end

    def by_name(name)
      matches = employees_by_name.select { |employee_name, _employee| same_name?(employee_name, normalize(name)) }.map(&:last)
      matches.first if matches.one?
    end

    def same_name?(employee_name, name)
      employee_name == name || (employee_name.length == TRUNCATED_NAME_LENGTH && name.start_with?(employee_name))
    end

    def employees_by_name
      @employees_by_name ||= tenant.employees.map { |employee| [normalize(employee.name), employee] }
    end

    def normalize(name)
      I18n.transliterate(name.to_s).upcase.squish
    end
  end
end
