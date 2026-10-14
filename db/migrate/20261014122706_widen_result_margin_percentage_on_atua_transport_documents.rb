class WidenResultMarginPercentageOnAtuaTransportDocuments < ActiveRecord::Migration[8.1]
  def up
    change_column :atua_transport_documents, :result_margin_percentage, :decimal, precision: 12, scale: 4
  end

  def down
    change_column :atua_transport_documents, :result_margin_percentage, :decimal, precision: 7, scale: 4
  end
end
