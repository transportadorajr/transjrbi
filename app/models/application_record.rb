class ApplicationRecord < ActiveRecord::Base
  extend EnumHelpers

  primary_abstract_class

  class << self
    def time_based_flag(name, suffix: :at, canceled_by: [])
      field_name = :"#{name}_#{suffix}"
      canceled_by = Array(canceled_by)

      define_method(name) { send(:"#{name}?") }
      define_method(:"#{name}?") { send(:"#{field_name}?") && canceled_by.none? { |f| send(:"#{f}?") } }
      define_method(:"#{name}=") do |bool|
        bool = ActiveModel::Type::Boolean.new.cast(bool)
        send(:"#{field_name}=", bool ? send(field_name) || Time.current : nil)
      end

      define_method(:"#{name}_changed?") { send(:"#{field_name}_change") == [nil, send(field_name)] }

      scope name.to_sym, -> { where(field_name => (..Time.current), **canceled_by.index_with([nil, Time.current..])) }

      klass = self

      scope :"not_#{name}", -> {
        conditions = [klass.where(field_name => [nil, Time.current..])]
        conditions += canceled_by.map { klass.where(it => ..Time.current) }

        merge(conditions.reduce(:or))
      }
    end
  end

  def confirmation_name
    self.class.model_name.human
  end
end
