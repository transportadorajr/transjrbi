module Dashboard
  class AdvanceIcms
    PENDING_ICMS_SQL = "CASE WHEN status = 'pending' THEN icms_cents ELSE 0 END".freeze

    GroupRow = Data.define(:key, :label, :count, :icms, :guide, :pending, :gross) do
      def share
        return if gross.zero?

        (guide.to_d / gross.to_d * 100).round(2)
      end
    end

    def initialize(documents, billed_documents)
      @documents = documents
      @billed_documents = billed_documents
    end

    def monthly_data
      guides = monthly_sum('guide_cents')
      pending = monthly_sum(PENDING_ICMS_SQL)

      [{ name: I18n.t('dashboards.advance_icms.guides'), data: guides.transform_keys { |month| month_label(month) } },
       { name: I18n.t('dashboards.advance_icms.pending'), data: pending.transform_keys { |month| month_label(month) } }]
    end

    def monthly?
      facts.exists?
    end

    def group_rows
      @group_rows ||= facts.group(Arel.sql('customer_group_id'))
        .pluck(Arel.sql('customer_group_id'), Arel.sql('COUNT(*)'), Arel.sql('SUM(icms_cents)'), Arel.sql('SUM(guide_cents)'),
               Arel.sql("SUM(#{PENDING_ICMS_SQL})"))
        .map { |key, count, icms, guide, pending| build_group_row(key, count, icms, guide, pending) }
        .sort_by { |row| [-row.guide.cents, -row.pending.cents, I18n.transliterate(row.label).downcase] }
    end

    def overdue_count
      @overdue_count ||= documents.advance_icms_overdue.count
    end

    private

    attr_reader :documents, :billed_documents

    def facts
      @facts ||= documents.advance_icms_facts
    end

    def monthly_sum(expression)
      facts.group_by_month(Arel.sql('advance_icms_documents.issued_at')).sum(Arel.sql(expression))
        .transform_values { |cents| Money.from_cents(cents.to_i).to_d }
    end

    def month_label(month)
      I18n.l(month.to_date, format: :chart_month).capitalize
    end

    def build_group_row(key, count, icms, guide, pending)
      GroupRow.new(key:, label: group_names.fetch(key, I18n.t('dashboards.listing_groups.none.customer_group')), count: count.to_i,
                   icms: Money.from_cents(icms.to_i), guide: Money.from_cents(guide.to_i), pending: Money.from_cents(pending.to_i),
                   gross: billed_by_group.fetch(key&.to_s, Money.zero))
    end

    def group_names
      @group_names ||= CustomerGroup.where(id: facts.distinct.pluck(Arel.sql('customer_group_id')).compact).pluck(:id, :name).to_h
    end

    def billed_by_group
      @billed_by_group ||= ListingGroups.for_transport_documents(billed_documents, dimension: 'customer_group', net: false).rows
        .to_h { |row| [row.key, row.gross] }
    end
  end
end
