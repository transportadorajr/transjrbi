require 'rails_helper'

RSpec.describe MaintenanceOrderLabor do
  it 'requires the day worked and positive hours' do
    labor = build(:maintenance_order_labor, worked_on: nil, hours: 0)

    expect(labor).not_to be_valid
    expect(labor.errors.full_messages).to contain_exactly('Data não pode ficar em branco', 'Horas deve ser maior que 0')
  end

  it 'accepts a labor without hours' do
    expect(build(:maintenance_order_labor, hours: nil)).to be_valid
  end
end
