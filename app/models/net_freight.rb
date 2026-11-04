class NetFreight
  attr_reader :freight, :commission, :tonnage, :insurance, :international_insurance, :tarp_lining, :fuel, :expenses, :complement_credit, :complement_transfer, :toll

  class << self
    def for(transport_documents)
      documents = transport_documents.active.not_canceled
      document_ids = documents.select(:id)
      insurance, international_insurance = insurances_of(document_ids)

      new(
        freight: Money.from_cents(documents.sum(:freight_cents)),
        commission: Money.from_cents(FreightExpense.commission.where(transport_document_id: document_ids).sum(:amount_cents)),
        tonnage: Money.from_cents(FreightExpense.tonnage.where(transport_document_id: document_ids).sum(:amount_cents)),
        insurance:,
        international_insurance:,
        tarp_lining: Money.from_cents(FreightExpense.tarp_lining.where(transport_document_id: document_ids).sum(:amount_cents)),
        fuel: Money.from_cents(FreightExpense.fuel.where(transport_document_id: document_ids).sum(:amount_cents)),
        expenses: Money.from_cents(Atua::Expense.active.freight.where(cost_object_id: document_ids).sum(:total_cents)),
        complement_credit: Money.from_cents(complements_of(document_ids).sum(:freight_cents)),
        complement_transfer: Money.from_cents(documents.where.not(complemented_transport_document_id: nil).sum(:freight_cents)),
        toll: Money.from_cents(documents.sum(Atua::TransportDocument.discounted_toll)),
      )
    end

    private

    def insurances_of(document_ids)
      insurances = FreightExpense.insurance.where(transport_document_id: document_ids)
      international_cents = insurances.sum(:international_insurance_cents) + insurances.sum(:iof_cents)

      [Money.from_cents(insurances.sum(:amount_cents) - international_cents), Money.from_cents(international_cents)]
    end

    def complements_of(document_ids)
      Atua::TransportDocument.active.not_canceled.where(complemented_transport_document_id: document_ids)
    end
  end

  def initialize(freight:, commission:, tonnage:, insurance:, international_insurance:, tarp_lining:, fuel:, expenses:, complement_credit:,
                 complement_transfer:, toll:)
    @freight = freight
    @commission = commission
    @tonnage = tonnage
    @insurance = insurance
    @international_insurance = international_insurance
    @tarp_lining = tarp_lining
    @fuel = fuel
    @expenses = expenses
    @complement_credit = complement_credit
    @complement_transfer = complement_transfer
    @toll = toll
  end

  def net
    freight - commission - tonnage - insurance - international_insurance - tarp_lining - fuel - expenses + complement_credit - complement_transfer - toll
  end
end
