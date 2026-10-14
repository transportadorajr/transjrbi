require 'rails_helper'

RSpec.describe CustomerGroupForm do
  let(:tenant) { create(:tenant) }

  describe '#save' do
    it 'creates an active group with one term per line' do
      form = described_class.new(tenant:, name: '  TERRAFEC ', terms: "2JM\n terrinha  alimentos \n\n2JM", active: '1')

      expect { expect(form.save).to be(true) }.to change(CustomerGroup, :count).by(1)

      customer_group = CustomerGroup.last
      expect(customer_group.tenant).to eq(tenant)
      expect(customer_group.name).to eq('TERRAFEC')
      expect(customer_group.terms).to eq(['2JM', 'terrinha alimentos'])
      expect(customer_group.activated_at).to be_present
    end

    it 'creates an inactive group without terms' do
      form = described_class.new(tenant:, name: 'MOVISTAR', terms: '', active: '0')

      expect(form.save).to be(true)

      customer_group = CustomerGroup.last
      expect(customer_group.terms).to eq([])
      expect(customer_group.activated_at).to be_nil
    end

    it 'rejects a group without a name' do
      form = described_class.new(tenant:, name: ' ')

      expect { expect(form.save).to be_falsey }.not_to change(CustomerGroup, :count)
      expect(form.errors[:name]).to eq(['não pode ficar em branco'])
    end

    it 'rejects a term without letters or numbers' do
      form = described_class.new(tenant:, name: 'TERRAFEC', terms: "TERRAFEC\n- / -")

      expect { expect(form.save).to be_falsey }.not_to change(CustomerGroup, :count)
      expect(form.errors[:terms]).to eq(['devem ter ao menos uma letra ou um número em cada linha'])
    end

    context 'when the name is already taken' do
      let!(:existing_group) { create(:customer_group, tenant:, name: 'TERRAFEC') }

      it 'rejects the duplicated name in the same tenant' do
        form = described_class.new(tenant:, name: 'TERRAFEC')

        expect { expect(form.save).to be_falsey }.not_to change(CustomerGroup, :count)
        expect(form.errors[:name]).to eq(['já está em uso por outro grupo'])
      end

      it 'accepts the name in another tenant' do
        form = described_class.new(tenant: create(:tenant), name: 'TERRAFEC')

        expect { expect(form.save).to be(true) }.to change(CustomerGroup, :count).by(1)
      end
    end
  end

  describe '.for_customer_group' do
    let(:activated_at) { Time.zone.local(2026, 10, 1, 8) }
    let!(:customer_group) { create(:customer_group, tenant:, name: 'TERRAFEC', terms: %w[2JM TERRAFEC], activated_at:) }

    it 'loads the terms one per line' do
      form = described_class.for_customer_group(customer_group)

      expect(form.name).to eq('TERRAFEC')
      expect(form.terms).to eq("2JM\nTERRAFEC")
      expect(form.active).to be(true)
      expect(form).to be_persisted
    end

    it 'updates the group keeping its own name available and the activation date' do
      form = described_class.for_customer_group(customer_group)
      form.assign_attributes(terms: "TERRAFEC\nTERRINHA ALIMENTOS", active: '1')

      expect { expect(form.save).to be(true) }.not_to change(CustomerGroup, :count)

      customer_group.reload
      expect(customer_group.name).to eq('TERRAFEC')
      expect(customer_group.terms).to eq(['TERRAFEC', 'TERRINHA ALIMENTOS'])
      expect(customer_group.activated_at).to eq(activated_at)
    end

    it 'deactivates the group' do
      form = described_class.for_customer_group(customer_group)
      form.assign_attributes(active: '0')

      expect(form.save).to be(true)
      expect(customer_group.reload.activated_at).to be_nil
    end
  end
end
