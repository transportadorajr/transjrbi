# frozen_string_literal: true

module RuboCop
  module Cop
    module Rails
      class PreferEnumOptionsForSelect < Base
        extend AutoCorrector

        @enum_index = nil
        class << self
          attr_accessor :enum_index
        end

        MSG = 'Avoid manually mapping enums with I18n. Use `enum_options_for_select(:%<enum>s)` instead.'

        # Matches:
        #   Something.<plural_enum_method>.map { |k, v| [I18n.t("...#{v}"), k] }
        # where block arg order may be |key, value|.
        def_node_matcher :manual_enum_mapping_block?, <<~PATTERN
          (block
            (send
              (send $_receiver $_plural_enum_method) :map)
            (args
              (arg $_key)
              (arg $_value))
            $(array
              (send
                (const {nil? cbase} :I18n)
                :t
                (dstr (str _) (begin (lvar $_value))))
              (lvar $_key)))
        PATTERN

        # Matches enum declarations:
        #   enum status: { ... }
        def_node_matcher :enum_hash_style?, <<~PATTERN
          (send nil? :enum (hash <(pair (sym $_enum_name) _) ...>))
        PATTERN

        # Matches enum declarations:
        #   enum :status, { ... }
        def_node_matcher :enum_positional_style?, <<~PATTERN
          (send nil? :enum (sym $_enum_name) ...)
        PATTERN

        def on_block(node)
          manual_enum_mapping_block?(node) do |receiver_node, plural_method, _key_var, _value_var, _array_node|
            enum_name = infer_enum_name(plural_method)
            next unless enum_name

            # Only flag when we can confirm `enum enum_name: ...` exists on that model
            receiver_const = const_name(receiver_node)
            next unless receiver_const

            next unless enum_defined_in_project?(receiver_const, enum_name)

            add_offense(node, message: format(MSG, enum: enum_name)) do |corrector|
              corrector.replace(node, "#{receiver_node.source}.enum_options_for_select(:#{enum_name})")
            end
          end
        end

        private

        # Infer enum name from pluralized enum methods, e.g. statuses -> status.
        # Uses a small heuristic and avoids ActiveSupport dependency.
        def infer_enum_name(plural_method)
          m = plural_method.to_s
          return nil if m.empty?

          # Basic singularization heuristics.
          singular =
            if m.end_with?('ies')
              m.sub(/ies\z/, 'y')
            elsif m.end_with?('ses')
              # statuses -> status, processes -> process
              m.sub(/es\z/, '') # rubocop:disable Performance/DeleteSuffix
            elsif m.end_with?('s')
              m.sub(/s\z/, '') # rubocop:disable Performance/DeleteSuffix
            end

          return nil if singular.nil? || singular.empty? # rubocop:disable Rails/Blank

          singular.to_sym
        end

        # Extract fully-qualified const name from a const node.
        # Supports:
        #   (const nil? :User)
        #   (const (const nil? :Admin) :User)
        def const_name(node)
          return nil unless node&.const_type?

          parts = []
          cur = node
          while cur&.const_type?
            parts << cur.children[1].to_s
            cur = cur.children[0]
          end

          parts.reverse.join('::')
        end

        def enum_index
          self.class.enum_index ||= build_enum_index
        end

        def build_enum_index
          index = Hash.new { |h, k| h[k] = Set.new }

          model_files = Dir.glob(File.join(Dir.pwd, 'app/models/**/*.rb'))
          model_files.each do |path|
            source = File.read(path)
            processed = RuboCop::ProcessedSource.new(source, target_ruby_version, path)
            ast = processed.ast
            next unless ast

            nesting = []

            walk = ->(n) do
              return unless n.is_a?(Parser::AST::Node)

              if n.class_type? || n.module_type?
                name_node = n.children[0]
                local_name = const_name(name_node)
                if local_name
                  full_name = qualify_name(local_name, nesting)

                  nesting << full_name
                  # Module body is at children[1], class body is at children[2]
                  body = n.module_type? ? n.children[1] : n.children[2]
                  walk.call(body)
                  nesting.pop
                  return
                end
              end

              if n.send_type? && n.children[1] == :enum && n.children[0].nil?
                current_scope = nesting.last
                if current_scope
                  enum_hash_style?(n) { |enm| index[current_scope] << enm }
                  enum_positional_style?(n) { |enm| index[current_scope] << enm }
                end
              end

              n.children.each { |child| walk.call(child) }
            end

            walk.call(ast)
          rescue StandardError
            next
          end

          index
        end

        def qualify_name(local_name, nesting)
          return local_name if local_name.include?('::')
          return local_name if nesting.empty?

          "#{nesting.last}::#{local_name}"
        end

        def enum_defined_in_project?(receiver_const_name, enum_name)
          enum_index[receiver_const_name].include?(enum_name)
        end
      end
    end
  end
end
