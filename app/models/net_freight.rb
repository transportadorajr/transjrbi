class NetFreight
  attr_reader :freight, :commission, :tonnage, :insurance, :expenses

  class << self
    def for(transport_documents)
      documents = transport_documents.active.not_canceled
      document_ids = documents.select(:id)

      new(
        freight: Money.from_cents(documents.sum(:freight_cents)),
        commission: Money.from_cents(FreightExpense.commission.where(transport_document_id: document_ids).sum(:amount_cents)),
        tonnage: Money.from_cents(FreightExpense.tonnage.where(transport_document_id: document_ids).sum(:amount_cents)),
        insurance: Money.from_cents(FreightExpense.insurance.where(transport_document_id: document_ids).sum(:amount_cents)),
        expenses: Money.from_cents(Atua::Expense.active.freight.where(cost_object_id: document_ids).sum(:total_cents)),
      )
    end
  end

  def initialize(freight:, commission:, tonnage:, insurance:, expenses:)
    @freight = freight
    @commission = commission
    @tonnage = tonnage
    @insurance = insurance
    @expenses = expenses
  end

  def net
    freight - commission - tonnage - insurance - expenses
  end
end
