require 'rails_helper'

describe 'Own fleet' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Frota própria', slug: 'own_fleet') }

  context 'without a signed in user' do
    scenario 'redirects the fleet to the login screen' do
      visit own_fleet_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'does not change the fleet' do
      expect do
        page.driver.submit :patch, own_fleet_path, { own_fleet: { plates: 'AJR4391' } }
      end.not_to change(OwnFleet, :count)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in' do
    let!(:owner) { create(:user, tenant:, name: 'Bruna Dona', user_type: :owner) }

    before { login_as(owner, scope: :user) }

    context 'when the tenant has no fleet' do
      before { create(:own_fleet, tenant: other_tenant, plates: %w[INT6R00]) }

      scenario 'shows an empty fleet from the registrations menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Cadastros'
          click_on 'Frota própria'
        end

        expect(page).to have_current_path(own_fleet_path)
        expect(OwnFleet.where(tenant:).count).to eq(0)
        expect(dl_to_hash('#own_fleet_data')).to eq('Quantidade de placas' => '0', 'Placas' => '-')
      end

      scenario 'registers the fleet pasting the lines of the RNTRC statement' do
        visit edit_own_fleet_path

        fill_in 'Placas da frota própria', with: <<~TEXT
          1 ALC-6D72/PR Automotor CAMINHÃO TRATOR 00810814129 NÃO PRÓPRIO ATIVO
          4 AQZ-1D12/PR Implemento SEMI-REBOQUE 00125211805 NÃO LEASING ATIVO
        TEXT

        expect { click_on 'Salvar Alterações' }.to change(OwnFleet, :count).by(1)

        expect(page).to have_current_path(own_fleet_path)
        expect(page).to have_text('Frota própria atualizada com 2 placas.')
        expect(OwnFleet.last).to have_attributes(tenant:, plates: %w[ALC6D72 AQZ1D12])
        expect(dl_to_hash('#own_fleet_data')).to eq('Quantidade de placas' => '2', 'Placas' => 'ALC6D72, AQZ1D12')
      end
    end

    context 'when the tenant has a fleet' do
      let!(:own_fleet) { create(:own_fleet, tenant:, plates: %w[AJR4391 RHJ5A50]) }

      scenario 'replaces the plates of the fleet' do
        visit own_fleet_path
        click_on 'Alterar'

        expect(page).to have_field('Placas da frota própria', with: "AJR4391\nRHJ5A50")

        fill_in 'Placas da frota própria', with: 'BCN-3I00'

        expect { click_on 'Salvar Alterações' }.not_to change(OwnFleet, :count)

        expect(page).to have_text('Frota própria atualizada com 1 placa.')
        expect(own_fleet.reload.plates).to eq(%w[BCN3I00])
      end
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }

    before { login_as(operator, scope: :user) }

    context 'with read access to the fleet' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }
      let!(:own_fleet) { create(:own_fleet, tenant:, plates: %w[AJR4391]) }

      scenario 'shows the fleet without the edit button' do
        visit own_fleet_path

        expect(Access.count).to eq(1)
        expect(dl_to_hash('#own_fleet_data')).to eq('Quantidade de placas' => '1', 'Placas' => 'AJR4391')
        expect(page).to have_no_link('Alterar', exact: true)
      end
    end

    context 'without access to the fleet' do
      scenario 'is sent back with an access denied message' do
        visit own_fleet_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end
  end
end
