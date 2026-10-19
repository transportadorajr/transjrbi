class ReplaceDueOnWithDueDatesOnAtuaTransportDocuments < ActiveRecord::Migration[8.1]
  def up
    add_column :atua_transport_documents, :due_dates, :date, array: true, default: [], null: false
    execute 'UPDATE atua_transport_documents SET due_dates = ARRAY[due_on] WHERE due_on IS NOT NULL'
    remove_column :atua_transport_documents, :due_on
  end

  def down
    add_column :atua_transport_documents, :due_on, :date
    execute 'UPDATE atua_transport_documents SET due_on = (SELECT MAX(due_date) FROM UNNEST(due_dates) AS due_date)'
    remove_column :atua_transport_documents, :due_dates
  end
end
