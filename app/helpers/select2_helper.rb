module Select2Helper
  def select2_hidden_fields(name, selected, multiple)
    return hidden_field_tag(name, selected, id: nil, data: { select2_target: 'hiddenInput' }) unless multiple

    values = Array(selected).compact_blank.presence || ['']

    safe_join(values.map { |value| hidden_field_tag(name, value, id: nil, data: { select2_target: 'hiddenInput' }) })
  end
end
