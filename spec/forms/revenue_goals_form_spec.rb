require 'rails_helper'

RSpec.describe RevenueGoalsForm do
  let(:tenant) { create(:tenant) }
  let(:month) { Date.new(2026, 11, 1) }

  let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }
  let!(:gerdau) { create(:customer_group, tenant:, name: 'GERDAU', activated_at: nil) }
  let!(:arcelor) { create(:atua_customer, tenant:, name: 'ARCELORMITTAL') }
  let!(:vale_do_aco) { create(:macro_region, tenant:, name: 'VALE DO AÇO/MG') }

  before do
    create(:own_fleet, tenant:, plates: %w[RHJ5A50 AJR4391])
    create(:atua_transport_document, tenant:, plate: 'AJR4391', taker_code: arcelor.code, origin_macro_region: vale_do_aco, freight_cents: 800_000,
                                     issued_at: Time.zone.local(2026, 10, 20, 10))
  end

  def form(**attributes)
    described_class.new(tenant:, month: '2026-11', **attributes)
  end

  def line_values(lines)
    lines.map { [it.key, it.name, it.amount, it.reference_cents] }
  end

  describe '.for_month' do
    it 'lists the own fleet and the plates that already have a goal with the billing of the previous month' do
      create(:revenue_goal, tenant:, month:, amount_cents: 15_000_000)
      create(:revenue_goal, :vehicle, tenant:, month:, plate: 'XYZ9K87', amount_cents: 1_234_550)

      loaded = described_class.for_month(tenant, month)

      expect(loaded.month).to eq('2026-11')
      expect(loaded.company).to eq('150.000,00')
      expect(line_values(loaded.vehicles)).to eq([['AJR4391', 'AJR4391', nil, 800_000], ['RHJ5A50', 'RHJ5A50', nil, 0],
                                                  ['XYZ9K87', 'XYZ9K87', '12.345,50', 0]])
      expect(loaded.total_cents(:vehicles)).to eq(1_234_550)
      expect(loaded.customer_groups.map { [it.name, it.amount] }).to eq([['USIMINAS', nil]])
    end

    it 'keeps a deactivated customer group that already has a goal' do
      create(:revenue_goal, :customer_group, tenant:, month:, customer_group: gerdau, amount_cents: 2_000_000)

      loaded = described_class.for_month(tenant, month)

      expect(loaded.customer_groups.map { [it.name, it.amount] }).to eq([['GERDAU', '20.000,00'], ['USIMINAS', nil]])
      expect(loaded.total_cents(:customer_groups)).to eq(2_000_000)
    end

    it 'lists the macro regions with the billing of the previous month' do
      create(:macro_region, tenant:, name: 'BAHIA', state: 'BA')

      loaded = described_class.for_month(tenant, month)

      expect(loaded.regions.map { [it.name, it.reference_cents] }).to eq([['BAHIA', 0], ['VALE DO AÇO/MG', 800_000]])
      expect(loaded.lines.keys).to eq(%i[vehicles customer_groups regions])
    end
  end

  describe '#save' do
    it 'creates, updates and removes the goals of the month' do
      create(:revenue_goal, :vehicle, tenant:, month:, plate: 'RHJ5A50', amount_cents: 500_000)
      create(:revenue_goal, tenant:, month: month.prev_month, amount_cents: 900_000)

      saved = form(company: '120.000,00', vehicles_attributes: { '0' => { key: 'ajr4391', amount: '25.000,50' }, '1' => { key: 'RHJ5A50', amount: '' } })

      expect { expect(saved.save).to be(true) }.to change(RevenueGoal, :count).by(1)
      expect(tenant.revenue_goals.for_month(month).map { [it.target_type, it.plate, it.amount_cents] })
        .to contain_exactly(['company', nil, 12_000_000], ['vehicle', 'AJR4391', 2_500_050])
      expect(tenant.revenue_goals.for_month(month.prev_month).sole.amount_cents).to eq(900_000)
    end

    it 'saves the customer group and region goals' do
      saved = form(customer_groups_attributes: { '0' => { key: usiminas.id.to_s, amount: '70.000,00' } },
                   regions_attributes: { '0' => { key: vale_do_aco.id.to_s, amount: '90.000,00' } })

      expect { expect(saved.save).to be(true) }.to change(RevenueGoal, :count).by(2)
      expect(tenant.revenue_goals.customer_group.sole).to have_attributes(customer_group_id: usiminas.id, amount_cents: 7_000_000)
      expect(tenant.revenue_goals.region.sole).to have_attributes(macro_region_id: vale_do_aco.id, amount_cents: 9_000_000)
    end

    context 'with a customer group of another tenant' do
      let!(:other) { create(:customer_group, name: 'OUTRA') }

      it 'rejects it' do
        invalid = form(customer_groups_attributes: { '0' => { key: other.id.to_s, amount: '10,00' }, '1' => { key: usiminas.id.to_s, amount: '0' } })

        expect(invalid.save).to be_falsey
        expect(invalid.errors.full_messages).to contain_exactly("O grupo de clientes #{other.id} não está ativo.",
                                                                'A meta do grupo de clientes USIMINAS deve ser maior que 0.')
      end
    end

    it 'rejects a macro region of another tenant' do
      other_region = create(:macro_region, name: 'OUTRA REGIÃO')

      invalid = form(regions_attributes: { '0' => { key: other_region.id.to_s, amount: '10,00' }, '1' => { key: vale_do_aco.id.to_s, amount: 'abc' } })

      expect { invalid.save }.not_to change(RevenueGoal, :count)
      expect(invalid.errors.full_messages).to contain_exactly("A macro região #{other_region.id} não está cadastrada.",
                                                              'A meta da macro região VALE DO AÇO/MG deve ser maior que 0.')
    end

    it 'rejects an invalid month' do
      invalid = form(month: '2026-13')

      expect(invalid.save).to be_falsey
      expect(invalid.errors[:month]).to be_present
    end

    it 'rejects a non positive amount' do
      invalid = form(company: '0', vehicles_attributes: { '0' => { key: 'AJR4391', amount: 'abc' } })

      expect(invalid.save).to be_falsey
      expect(invalid.errors.full_messages).to contain_exactly('Meta da transportadora deve ser maior que 0',
                                                              'A meta do veículo AJR4391 deve ser maior que 0.')
    end

    it 'rejects a plate outside the own fleet' do
      invalid = form(vehicles_attributes: { '0' => { key: 'XYZ9K87', amount: '100,00' } })

      expect { invalid.save }.not_to change(RevenueGoal, :count)
      expect(invalid.errors.full_messages).to eq(['O veículo XYZ9K87 não está na frota própria.'])
    end
  end
end
