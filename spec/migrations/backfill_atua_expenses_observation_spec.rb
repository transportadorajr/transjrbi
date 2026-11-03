require 'rails_helper'
require Rails.root.join('db/migrate/20261103195502_backfill_atua_expenses_observation')

RSpec.describe BackfillAtuaExpensesObservation do
  subject(:migration) { described_class.new.tap { |instance| instance.verbose = false } }

  let!(:tenant) { create(:tenant) }

  context 'when the expense rows carry an observation' do
    let!(:expense) do
      create(:atua_expense, tenant:, code: 1, raw_data: [{ 'ds_observacao_titulo' => '  SEGURO INTERNACIONAL JUNES PEDIU ' }])
    end

    it 'copies the observation of the first row' do
      expect { migration.up }.to change { expense.reload.observation }.from(nil).to('SEGURO INTERNACIONAL JUNES PEDIU')
    end
  end

  context 'when the observation of the expense rows is blank' do
    let!(:expense) { create(:atua_expense, tenant:, code: 2, raw_data: [{ 'ds_observacao_titulo' => ' ' }]) }

    it 'leaves the observation empty' do
      migration.up

      expect(expense.reload.observation).to be_nil
    end
  end
end
