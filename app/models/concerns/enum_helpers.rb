module EnumHelpers
  def enum_options_for_select(attribute, except: [])
    (send(attribute.to_s.pluralize).keys - Array(except).map(&:to_s))
      .map { |key| [human_enum_name(attribute, key), key] }
  end

  def human_enum_name(enum, value)
    enum_translations(enum)[value.presence&.to_sym] || value.to_s.humanize
  end

  def enum_translations(enum)
    I18n.t(enum, scope: [:enums, model_name.param_key])
  end

  def _enum(name, ...)
    super

    define_enum_name(name)
  end

  def define_enum_name(name)
    define_method :"#{name}_name" do
      self.class.human_enum_name(name, public_send(name))
    end
  end
end
