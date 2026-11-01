class TripExpenses
  Item = Data.define(:kind, :record, :transport_document, :posted_on, :amount)

  attr_reader :items, :total

  class << self
    def for(transport_documents, internal:, atua:)
      documents = transport_documents.active.not_canceled
      items = []
      items += freight_expense_items(documents) + toll_items(documents) if internal
      items += expense_items(documents) if atua

      new(items)
    end

    private

    def freight_expense_items(documents)
      FreightExpense.where(transport_document_id: documents.select(:id))
        .preload(:transport_document, :commission_rule, :tonnage_rate, :insurance_rate, :truck_group)
        .order(:kind_type, :id).map do |freight_expense|
          Item.new(kind: :freight_expense, record: freight_expense, transport_document: freight_expense.transport_document,
                   posted_on: nil, amount: freight_expense.amount)
        end
    end

    def toll_items(documents)
      table = Atua::TransportDocument
      documents.select(table.arel_table[Arel.star], table.discounted_toll.as('discounted_toll_cents')).filter_map do |document|
        cents = document['discounted_toll_cents'].to_i
        next unless cents.positive?

        Item.new(kind: :toll, record: document, transport_document: document, posted_on: nil, amount: Money.from_cents(cents))
      end
    end

    def expense_items(documents)
      Atua::Expense.active.freight.where(cost_object_id: documents.select(:id)).preload(:cost_object)
        .order(Atua::Expense.arel_table[:posted_at].desc.nulls_last, id: :desc).map do |expense|
          Item.new(kind: :expense, record: expense, transport_document: expense.cost_object, posted_on: expense.posted_on,
                   amount: Money.from_cents(expense.total_cents.to_i))
        end
    end
  end

  def initialize(items)
    @items = items.each_with_index.sort_by { |item, index| [item.transport_document.number, index] }.map(&:first)
    @total = items.sum(Money.from_cents(0), &:amount)
  end
end
