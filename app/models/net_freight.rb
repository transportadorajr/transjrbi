class NetFreight
  attr_reader :freight, :commission, :tonnage, :insurance, :tarp_lining, :fuel, :expenses, :toll

  class << self
    def for(transport_documents)
      documents = transport_documents.active.not_canceled
      document_ids = documents.select(:id)

      new(
        freight: Money.from_cents(documents.sum(:freight_cents)),
        commission: Money.from_cents(FreightExpense.commission.where(transport_document_id: document_ids).sum(:amount_cents)),
        tonnage: Money.from_cents(FreightExpense.tonnage.where(transport_document_id: document_ids).sum(:amount_cents)),
        insurance: Money.from_cents(FreightExpense.insurance.where(transport_document_id: document_ids).sum(:amount_cents)),
        tarp_lining: Money.from_cents(FreightExpense.tarp_lining.where(transport_document_id: document_ids).sum(:amount_cents)),
        fuel: Money.from_cents(FreightExpense.fuel.where(transport_document_id: document_ids).sum(:amount_cents)),
        expenses: Money.from_cents(Atua::Expense.active.freight.where(cost_object_id: document_ids).sum(:total_cents)),
        toll: Money.from_cents(documents.sum(Arel::Nodes::Grouping.new(Atua::TransportDocument.toll_vouchers_total.arel))),
      )
    end
  end

  def initialize(freight:, commission:, tonnage:, insurance:, tarp_lining:, fuel:, expenses:, toll:)
    @freight = freight
    @commission = commission
    @tonnage = tonnage
    @insurance = insurance
    @tarp_lining = tarp_lining
    @fuel = fuel
    @expenses = expenses
    @toll = toll
  end

  def net
    freight - commission - tonnage - insurance - tarp_lining - fuel - expenses - toll
  end
end
