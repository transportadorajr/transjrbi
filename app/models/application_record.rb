class ApplicationRecord < ActiveRecord::Base
  extend EnumHelpers

  primary_abstract_class

  class << self
    def monetize(*fields, **)
      super

      fields.each do |field|
        field = field.to_s.delete_suffix('_cents')

        define_method(:"formatted_#{field}") do
          send(field)&.format(symbol: nil)
        end

        define_method(:"formatted_#{field}=") do |value|
          send(:"#{field}=", value)
        end
      end
    end

    def ingest(many, callbacks: false, **)
      many = Array.wrap(many)

      ids = upsert_all(many, unique_by: ingest_unique_by, **).rows.pluck(0)

      many.each_with_index.map { |attributes, i| attributes.merge(id: ids[i]) }.tap do |result|
        next unless callbacks

        result.each do |h|
          record = new(**h)

          record.run_callbacks(:save) { false }
          record.run_callbacks(:create) { false }
        end
      end
    end

    def ingest_unique_by
      @ingest_unique_by ||= connection.indexes(table_name).find(&:unique)&.columns&.map(&:to_sym) || [:id]
    end

    def where_tuple_in(columns, tuples)
      columns = Arel::Nodes::Grouping.new(columns.map { |c| arel_table[c] })
      tuples = tuples.map { |tuple| Arel::Nodes::Grouping.new(tuple.map { |value| Arel::Nodes.build_quoted(value) }) }
      where(Arel::Nodes::In.new(columns, tuples))
    end

    def where_tuple_in_select(columns, tuples)
      columns = Arel::Nodes::Grouping.new(columns.map { |c| arel_table[c] })
      where(Arel::Nodes::In.new(columns, tuples))
    end

    def time_based_flag(name, suffix: :at, canceled_by: [])
      field_name = :"#{name}_#{suffix}"
      canceled_by = Array(canceled_by)

      define_method(name) { send(:"#{name}?") }
      define_method(:"#{name}?") { send(:"#{field_name}?") && canceled_by.none? { |f| send(:"#{f}?") } }
      define_method(:"#{name}=") do |bool|
        bool = ActiveModel::Type::Boolean.new.cast(bool)
        send(:"#{field_name}=", bool ? send(field_name) || Time.current : nil)
      end

      # Only reports `<field>_changed?` if it was `nil` before and now it's the current value
      define_method(:"#{name}_changed?") { send(:"#{field_name}_change") == [nil, send(field_name)] }

      scope name.to_sym, -> { where(field_name => (..Time.current), **canceled_by.index_with([nil, Time.current..])) }

      klass = self

      scope :"not_#{name}", -> {
        conditions = [klass.where(field_name => [nil, Time.current..])]
        conditions += canceled_by.map { klass.where(it => ..Time.current) }

        merge(conditions.reduce(:or))
      }
    end

    def sample
      offset(rand(count)).first
    end

    def has_tenant
      belongs_to :tenant, optional: true

      before_create -> { self.tenant ||= Current.tenant }
    end

    def accepts_text_into_json_field(field, accept_empty: true)
      define_method :"text_#{field}" do
        cached = instance_variable_get(:"@text_#{field}")
        return cached if cached

        JSON.pretty_generate(send(field)) if send(field).is_a?(Hash)
      end

      define_method :"text_#{field}=" do |raw|
        instance_variable_set(:"@text_#{field}", raw)
        assign_attributes(field => nil) if raw.blank?
      end

      define_method :"#{field}_validation" do
        cached = instance_variable_get(:"@text_#{field}")
        return if cached.blank?

        begin
          parsed = JSON.parse(cached)
          raise JSON::ParserError if !accept_empty && parsed.blank?

          assign_attributes(field => parsed)
        rescue JSON::ParserError => _e
          errors.add(:"text_#{field}", :invalid)
        end
      end

      validate :"#{field}_validation"
    end

    def owner_flag(owner_field)
      define_method(:method_missing) do |method_name, *args, &block|
        if method_name.to_s.end_with?('?') && args.empty?
          type_name = method_name.to_s.chomp('?').camelize
          return send(owner_field) == type_name if type_name.safe_constantize
        end
        super(method_name, *args, &block)
      end

      define_method(:respond_to_missing?) do |method_name, include_private = false|
        (method_name.to_s.end_with?('?') && method_name.to_s.chomp('?').camelize.safe_constantize.present?) || super(method_name, include_private)
      end
    end
  end

  def confirmation_name
    self.class.model_name.human
  end
end
