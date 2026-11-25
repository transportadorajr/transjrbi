module EmergencyContactsHelper
  PHONE_FORMATS = { 10 => /\A(\d{2})(\d{4})(\d{4})\z/, 11 => /\A(\d{2})(\d{5})(\d{4})\z/ }.freeze
  PHONE_COUNTRY_CODE = '+55'.freeze
  PHONE_MASK = ['(00) 00000-0000', '+00 0000000000[000]'].freeze

  def emergency_contacts_menu(emergency_contact)
    menus = []

    menus << emergency_contact_edit_menu(emergency_contact) if can?(:update, :emergency_contacts)
    menus << emergency_contact_destroy_menu(emergency_contact) if can?(:destroy, :emergency_contacts)

    menus
  end

  def emergency_contact_phone(phone)
    return "#{phone[0, 3]} #{phone[3..]}" if EmergencyContact.international_phone?(phone)

    match = PHONE_FORMATS[phone.to_s.size]&.match(phone.to_s)
    match ? "(#{match[1]}) #{match[2]}-#{match[3]}" : phone.to_s
  end

  def emergency_contact_phone_href(phone)
    EmergencyContact.international_phone?(phone) ? "tel:#{phone}" : "tel:#{PHONE_COUNTRY_CODE}#{phone}"
  end

  def emergency_contact_phone_link(phone, **options)
    return t('tax.blank') if phone.blank?

    link_to emergency_contact_phone_href(phone), class: ['text-nowrap', options[:class]] do
      safe_join([icon(:telephone, class: 'me-1'), emergency_contact_phone(phone)])
    end
  end

  def emergency_contact_phones(emergency_contact)
    phones = [emergency_contact.phone, emergency_contact.secondary_phone].compact_blank
    return t('tax.blank') if phones.empty?

    safe_join(phones.map { |phone| emergency_contact_phone_link(phone, class: 'd-block') }, ' ')
  end

  def emergency_contact_relationship(emergency_contact)
    emergency_contact.relationship_type ? emergency_contact.relationship_type_name : t('tax.blank')
  end

  def emergency_contact_summary(emergency_contact)
    return emergency_contact.name if emergency_contact.relationship_type.nil?

    t('emergency_contacts.index.contact', name: emergency_contact.name, relationship: emergency_contact.relationship_type_name)
  end

  def emergency_contacts_card(employee, emergency_contacts)
    return unless can?(:read, :emergency_contacts)

    render 'employees/emergency_contacts', employee:, emergency_contacts:
  end

  def employee_new_emergency_contact_button(employee)
    return unless can?(:create, :emergency_contacts)

    link_to new_employee_emergency_contact_path(employee), class: 'btn btn-outline-secondary btn-round' do
      safe_join([icon(:'person-plus', class: 'me-2'), t('employees.emergency_contacts.new_emergency_contact')])
    end
  end

  def emergency_contacts_employee_contacts(employee)
    return status_badge(t('emergency_contacts.index.missing'), kind: :warning) if employee.emergency_contacts.empty?

    render partial: 'emergency_contacts/contact', collection: employee.emergency_contacts, as: :emergency_contact
  end

  def emergency_contacts_employee_name(employee)
    return employee.name unless can?(:read, :employees)

    link_to employee.name, employee_path(employee, anchor: 'emergency_contacts')
  end

  def emergency_contact_relationship_options
    EmergencyContact.enum_options_for_select(:relationship_type)
  end

  def emergency_contact_company_type_options
    options_for_select(Employee.enum_options_for_select(:company_type), params[:company_type])
  end

  def emergency_contact_filter_options
    options_for_select(%w[registered missing].map { |value| [t("emergency_contacts.filters.contact_options.#{value}"), value] }, params[:contact])
  end

  def emergency_contacts_search_hidden_fields
    safe_join(%i[company_type contact].filter_map { |name| hidden_field_tag(name, params[name], id: nil) if params[name].is_a?(String) && params[name].present? })
  end

  def emergency_contact_form_url(emergency_contact_form)
    if emergency_contact_form.persisted?
      emergency_contact_path(emergency_contact_form.emergency_contact)
    else
      employee_emergency_contacts_path(emergency_contact_form.employee)
    end
  end

  def emergency_contact_form_submit_label(emergency_contact_form)
    t("helpers.submit.emergency_contact.#{emergency_contact_form.persisted? ? :update : :create}")
  end

  private

  def emergency_contact_edit_menu(emergency_contact)
    Menu.new(name: :edit, record: emergency_contact, url: edit_emergency_contact_path(emergency_contact), icon: :pencil)
  end

  def emergency_contact_destroy_menu(emergency_contact)
    Menu.new(
      name: :destroy,
      record: emergency_contact,
      url: emergency_contact_path(emergency_contact),
      icon: :'x-circle',
      data: {
        turbo_confirm: t('emergency_contacts.index.confirm_destroy'),
        turbo_method: :delete,
      },
    )
  end
end
