module RuboCop
  module Cop
    module Rails
      class JobQueueWithPriority < Base
        extend AutoCorrector

        MSG = 'All ActiveJob jobs must include a `queue_with_priority` declaration.'.freeze

        def on_class(node)
          return unless job_class?(node)
          return if queue_with_priority_declared?(node)

          add_offense(node.loc.name, message: MSG) do |corrector|
            insert_queue_with_priority(node, corrector)
          end
        end

        private

        def job_class?(node)
          node.parent_class&.const_name == 'ApplicationJob'
        end

        def queue_with_priority_declared?(node)
          node.each_descendant(:send).any? do |send_node|
            send_node.method_name == :queue_with_priority
          end
        end

        def insert_queue_with_priority(node, corrector)
          body = node.body
          return unless body

          first_child = body.children.first
          if first_child.respond_to?(:loc)
            corrector.insert_before(first_child.loc.expression, "queue_with_priority 1\n  ")
          else
            corrector.insert_before(node.loc.end, "\n  queue_with_priority 1\n")
          end
        end
      end
    end
  end
end
