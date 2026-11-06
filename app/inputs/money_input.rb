class MoneyInput < SimpleForm::Inputs::StringInput
  def input(wrapper_options = nil)
    options = merge_wrapper_options(input_html_options, wrapper_options)
    options[:inputmode] ||= 'decimal'
    options[:autocomplete] ||= 'off'
    options[:data] = money_data.merge(options[:data] || {})

    template.content_tag(:div, class: 'input-group') do
      template.safe_join([template.content_tag(:span, currency_format(:unit), class: 'input-group-text'),
                          @builder.text_field(attribute_name, options)])
    end
  end

  private

  def money_data
    { controller: 'money', money_separator_value: currency_format(:separator), money_delimiter_value: currency_format(:delimiter) }
  end

  def currency_format(key)
    I18n.t(key, scope: %i[number currency format])
  end
end
