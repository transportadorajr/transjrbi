module FreightTotalsHelper
  def freight_net_header(model, **)
    return unless can?(:read, :freight_expenses)

    sortable_header(model.human_attribute_name(:net), :net, first_direction: :desc, **)
  end

  def freight_net_cell(item, **)
    return unless can?(:read, :freight_expenses)

    content_tag(:td, freight_money(item.net_cents), **)
  end

  def freight_money(cents)
    tax_money(cents && Money.from_cents(cents))
  end

  def freight_sort_columns(model)
    columns = [[model.human_attribute_name(:customer_name), :customer_name], [model.human_attribute_name(:driver_name), :driver_name],
               [model.human_attribute_name(:gross), :gross, :desc]]
    columns << [model.human_attribute_name(:net), :net, :desc] if can?(:read, :freight_expenses)

    columns
  end
end
