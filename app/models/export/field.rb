module Export
  Field = Data.define(:name, :header, :type, :reader, :i18n_key) do
    class << self
      def computed(header, type = :string, &reader)
        new(name: header, header:, type:, reader:, i18n_key: nil)
      end

      def for(model, name, type = :string, &reader)
        new(name: name.to_s, header: model.human_attribute_name(name), type:, reader: reader || name.to_sym.to_proc,
            i18n_key: "activerecord.attributes.#{model.model_name.i18n_key}.#{name}")
      end
    end

    def translated?
      i18n_key.nil? || I18n.exists?(i18n_key)
    end

    def to_h
      { header:, type:, format: Format.for(type) }.compact
    end

    def value(record)
      Value.cast(type, reader.call(record))
    end
  end
end
