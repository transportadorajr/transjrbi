require 'rails_helper'

RSpec.describe DriverForm do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }

  describe '#save' do
    context 'with a driver without a display name' do
      it 'registers the display name squished and upcased' do
        form = described_class.new(tenant:, code: 760, display_name: '  jose   silva ')

        expect { form.save }.to change(Driver, :count).by(1)

        expect(Driver.last).to have_attributes(tenant_id: tenant.id, code: 760, display_name: 'JOSE SILVA')
      end
    end

    context 'with a driver that already has a display name' do
      let!(:driver) { create(:driver, tenant:, code: 760, display_name: 'JOSE SILVA') }
      let!(:stranger) { create(:driver, tenant: other_tenant, code: 760, display_name: 'OUTRO') }

      it 'updates the display name of the tenant driver only' do
        form = described_class.new(tenant:, code: 760, display_name: 'ZE')

        expect { form.save }.not_to change(Driver, :count)

        expect(driver.reload.display_name).to eq('ZE')
        expect(stranger.reload.display_name).to eq('OUTRO')
      end

      it 'clears a blank display name' do
        form = described_class.new(tenant:, code: 760, display_name: ' ')

        expect(form.save).to be(true)
        expect(driver.reload.display_name).to be_nil
      end
    end

    context 'with a display name that is too long' do
      it 'rejects the display name' do
        form = described_class.new(tenant:, code: 760, display_name: 'J' * 41)

        expect { form.save }.not_to change(Driver, :count)
        expect(form.errors.full_messages).to eq(['Nome de exibição é muito longo (máximo: 40 caracteres)'])
      end
    end

    context 'without a code' do
      it 'requires the code' do
        form = described_class.new(tenant:, display_name: 'JOSE')

        expect(form.save).to be_falsey
        expect(form.errors.attribute_names).to contain_exactly(:code)
      end
    end
  end
end
