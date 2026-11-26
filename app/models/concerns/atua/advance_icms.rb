module Atua
  module AdvanceIcms
    extend ActiveSupport::Concern

    ADVANCE_ICMS_CFOPS = [5932, 6932].freeze
    ADVANCE_ICMS_STATUSES = %i[paid divergent pending not_expected].freeze

    included do
      sortable :icms, -> { arel_table[:icms_cents] }
      sortable :advance_icms_guide, -> { Arel.sql('advance_icms_guide_cents') }

      scope :advance_icms, -> {
        active.not_canceled.freights.where(document_kind: MapTransportDocumentsCommand::DOCUMENT_KINDS['CTRC']).where(advance_icms_condition)
      }
      scope :with_advance_icms_guide, -> {
        select(arel_table[Arel.star], advance_icms_guide_total.as('advance_icms_guide_cents'),
               Arel::Nodes::Grouping.new(advance_icms_paid_by_taker).as('advance_icms_paid_by_taker'))
      }
      scope :by_advance_icms_status, ->(status) { where(advance_icms_status.eq(status.to_s)) }
      scope :by_origin_state, ->(state) { where(origin_state: state.to_s.strip.upcase) }
    end

    class_methods do
      def advance_icms_statuses
        ADVANCE_ICMS_STATUSES.index_by { |status| I18n.t(status, scope: 'advance_icms.statuses') }
      end

      def advance_icms_totals
        documents = all.select(advance_icms_status.as('status'), arel_table[:icms_cents], advance_icms_guide_total.as('guide_cents'))
        rows = unscoped.from(documents, :advance_icms_documents).group(Arel.sql('status'))
          .pluck(Arel.sql('status'), Arel.sql('COUNT(*)'), Arel.sql('SUM(icms_cents)'), Arel.sql('SUM(guide_cents)'))
        counts = rows.to_h { |status, count| [status.to_sym, count] }

        { count: counts.values.sum, counts: ADVANCE_ICMS_STATUSES.index_with { |status| counts.fetch(status, 0) },
          icms: Money.from_cents(rows.sum { |row| row[2].to_i }), guide: Money.from_cents(rows.sum { |row| row[3].to_i }) }
      end

      def advance_icms_guide_total
        expenses = Expense.arel_table

        Arel::Nodes::Grouping.new(
          Expense.active.freight.advance_icms.where(expenses[:cost_object_id].eq(arel_table[:id]))
            .select(sum_or_zero(expenses[:total_cents])).arel,
        )
      end

      def advance_icms_status
        guide = advance_icms_guide_total
        icms = Arel::Nodes::NamedFunction.new('COALESCE', [arel_table[:icms_cents], 0])

        Arel::Nodes::Case.new
          .when(guide.eq(0).and(advance_icms_paid_by_taker)).then(Arel::Nodes.build_quoted('pending'))
          .when(guide.eq(0)).then(Arel::Nodes.build_quoted('not_expected'))
          .when(guide.eq(icms)).then(Arel::Nodes.build_quoted('paid'))
          .else(Arel::Nodes.build_quoted('divergent'))
      end

      def advance_icms_paid_by_taker
        customers = Customer.arel_table

        Customer.joins(:customer_group).where(customers[:tenant_id].eq(arel_table[:tenant_id]))
          .where(customers[:code].eq(arel_table[:taker_code])).merge(CustomerGroup.pays_advance_icms).arel.exists
      end

      def advance_icms_condition
        expenses = Expense.arel_table
        guide = Expense.active.freight.advance_icms.where(expenses[:cost_object_id].eq(arel_table[:id]))

        arel_table[:cfop].in(ADVANCE_ICMS_CFOPS).and(arel_table[:icms_cents].gt(0)).or(guide.arel.exists)
      end
    end

    def advance_icms_guide
      Money.from_cents(self[:advance_icms_guide_cents].to_i)
    end

    def advance_icms_difference
      advance_icms_guide - Money.from_cents(icms_cents.to_i)
    end

    def advance_icms_status
      return self[:advance_icms_paid_by_taker] ? :pending : :not_expected if advance_icms_guide.zero?

      advance_icms_difference.zero? ? :paid : :divergent
    end
  end
end
