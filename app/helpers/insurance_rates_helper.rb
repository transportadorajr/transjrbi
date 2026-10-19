module InsuranceRatesHelper
  def insurance_rate_label
    t('insurance_rates.label')
  end

  def insurance_percentage(percentage)
    number_to_percentage(percentage, precision: 4, strip_insignificant_zeros: true)
  end

  def insurance_rate_percentage(insurance_rate, attribute)
    return t('tax.blank') unless insurance_rate

    insurance_percentage(insurance_rate.public_send(attribute))
  end

  def insurance_rate_edit_button
    return unless can?(:update, :insurance_rates)

    link_to edit_insurance_rate_path, class: 'btn btn-outline-secondary btn-round' do
      concat icon(:pencil, class: 'me-2')
      concat t('insurance_rates.show.edit')
    end
  end
end
