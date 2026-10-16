require 'rails_helper'

describe 'Tonnage rates' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Custos por tonelada', slug: 'tonnage_rates') }
  let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS', terms: ['USIMINAS']) }

  context 'without a signed in user' do
    scenario 'redirects the listing to the login screen' do
      visit tonnage_rates_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'does not create a rate' do
      expect do
        page.driver.submit :post, tonnage_rates_path, { tonnage_rate: { name: 'Brasiltec' } }
      end.not_to change(TonnageRate, :count)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when an admin is signed in' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

    before { login_as(admin, scope: :user) }

    context 'when there are no rates' do
      scenario 'shows the empty state message' do
        visit tonnage_rates_path

        expect(TonnageRate.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are rates' do
      let!(:cubatao) { create(:tonnage_rate, tenant:, customer_group: usiminas) }
      let!(:utinga) do
        create(:tonnage_rate, tenant:, customer_group: usiminas, nickname: 'Utinga', origin_city: 'Santo André', rate_cents: 1_802)
      end
      let!(:september) do
        create(:tonnage_rate, tenant:, customer_group: usiminas, nickname: nil, origin_city: 'Ipatinga', origin_state: 'MG',
                              valid_month: Date.new(2026, 9, 1), rate_cents: 850, activated_at: nil)
      end
      let!(:stranger_rate) do
        create(:tonnage_rate, tenant: other_tenant, customer_group: create(:customer_group, tenant: other_tenant), name: 'CUSTO DE OUTRA')
      end

      scenario 'lists the rates of the tenant from the registrations menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Cadastros'
          click_on 'Custos por tonelada'
        end

        expect(page).to have_current_path(tonnage_rates_path)
        expect(TonnageRate.count).to eq(4)
        expect(html_table_to_rows).to eq(
          [
            ['Origem', 'Nome', 'Grupo de clientes', 'Vigência', 'Média de', 'Valor por tonelada', 'Status', 'Ações'],
            ['Cubatão/SP (Cubatão)', 'Brasiltec', 'USIMINAS', '10/2026', '09/2026', 'R$ 12,57/t', 'Ativo', 'Opções Visualizar Alterar Excluir'],
            ['Santo André/SP (Utinga)', 'Brasiltec', 'USIMINAS', '10/2026', '09/2026', 'R$ 18,02/t', 'Ativo',
             'Opções Visualizar Alterar Excluir'],
            ['Ipatinga/MG', 'Brasiltec', 'USIMINAS', '09/2026', '08/2026', 'R$ 8,50/t', 'Inativo', 'Opções Visualizar Alterar Excluir'],
          ],
        )
        expect(page).to have_css('.counter-card', text: "Total de custos\n3")
        expect(page).to have_css('.counter-card', text: "Custos ativos\n2")
        expect(page).to have_css('.counter-card', text: "Custos inativos\n1")
        expect(page).to have_link('Novo Custo', href: new_tonnage_rate_path)
        expect(page).to have_no_text('CUSTO DE OUTRA')
      end

      scenario 'filters the rates by name, group, month and status' do
        visit tonnage_rates_path
        fill_in 'Nome do custo', with: 'brasil'
        select 'USIMINAS', from: 'Grupo de clientes'
        fill_in 'Vigência', with: '2026-10'
        select 'Ativo', from: 'Status'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows.drop(1).map(&:first)).to eq(['Cubatão/SP (Cubatão)', 'Santo André/SP (Utinga)'])
      end

      context 'when a rate was calculated on transport documents' do
        let!(:first_expense) { create(:freight_expense, :tonnage, tenant:, tonnage_rate: cubatao, amount_cents: 40_853) }
        let!(:second_expense) { create(:freight_expense, :tonnage, tenant:, tonnage_rate: cubatao, amount_cents: 12_570) }

        scenario 'shows the rate with its costs' do
          visit tonnage_rates_path
          click_on 'Cubatão/SP (Cubatão)'

          expect(page).to have_current_path(tonnage_rate_path(cubatao))
          expect(page).to have_css('h1.page-title', text: 'Brasiltec – Cubatão/SP (Cubatão)')
          expect(dl_to_hash('#tonnage_rate_data')).to eq(
            'Nome' => 'Brasiltec',
            'Grupo de clientes' => 'USIMINAS',
            'Origem' => 'Cubatão/SP (Cubatão)',
            'Vigência' => '10/2026',
            'Média de' => '09/2026',
            'Valor por tonelada' => 'R$ 12,57/t',
            'Status' => 'Ativo',
            'CT-es com o custo' => '2',
            'Total calculado' => 'R$ 534,23',
          )
        end
      end

      scenario 'does not show a rate of another tenant' do
        visit tonnage_rate_path(stranger_rate)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when creating a rate' do
      scenario 'creates the rate of the month and recalculates the freight expenses' do
        visit tonnage_rates_path
        click_on 'Novo Custo'
        select 'USIMINAS', from: 'Grupo de clientes'
        fill_in 'Nome', with: 'Brasiltec'
        fill_in 'Cidade de origem', with: 'São Paulo'
        fill_in 'UF de origem', with: 'SP'
        fill_in 'Apelido', with: 'TESP'
        fill_in 'Vigência', with: '2026-11'
        fill_in 'Valor por tonelada (R$)', with: '9,10'

        expect { click_on 'Cadastrar Custo' }.to change(TonnageRate, :count).by(1)
          .and have_enqueued_job(FreightExpenses::CalculateJob).with(tenant.id)

        tonnage_rate = TonnageRate.last
        expect(page).to have_current_path(tonnage_rate_path(tonnage_rate))
        expect(page).to have_text('Custo cadastrado com sucesso. As despesas do frete serão recalculadas em segundo plano.')
        expect(tonnage_rate).to have_attributes(tenant:, customer_group: usiminas, name: 'Brasiltec', nickname: 'TESP', origin_city: 'São Paulo',
                                                origin_state: 'SP', valid_month: Date.new(2026, 11, 1), rate_cents: 910)
        expect(tonnage_rate.activated_at).to be_present
      end

      scenario 'shows the errors of the required fields' do
        visit new_tonnage_rate_path

        expect { click_on 'Cadastrar Custo' }.to not_change(TonnageRate, :count)
          .and not_have_enqueued_job(FreightExpenses::CalculateJob)

        expect(page).to have_text('Grupo de clientes não pode ficar em branco')
        expect(page).to have_text('Valor por tonelada (R$) deve ser maior que 0')
      end
    end

    context 'when editing a rate' do
      let!(:tonnage_rate) { create(:tonnage_rate, tenant:, customer_group: usiminas) }

      scenario 'updates the rate and recalculates the freight expenses' do
        visit tonnage_rates_path
        within("#tonnage_rate_#{tonnage_rate.id} .inline-actions") { click_on 'Alterar' }

        expect(page).to have_current_path(edit_tonnage_rate_path(tonnage_rate))
        expect(page).to have_field('Valor por tonelada (R$)', with: '12,57')
        expect(page).to have_field('Vigência', with: '2026-10')

        fill_in 'Valor por tonelada (R$)', with: '12,80'
        uncheck 'Ativo'

        expect { click_on 'Salvar Alterações' }.to not_change(TonnageRate, :count)
          .and have_enqueued_job(FreightExpenses::CalculateJob).with(tenant.id)

        expect(page).to have_current_path(tonnage_rate_path(tonnage_rate))
        expect(page).to have_text('Custo atualizado com sucesso. As despesas do frete serão recalculadas em segundo plano.')

        tonnage_rate.reload
        expect(tonnage_rate.rate_cents).to eq(1_280)
        expect(tonnage_rate.activated_at).to be_nil
      end
    end

    context 'when removing a rate' do
      let!(:tonnage_rate) { create(:tonnage_rate, tenant:, customer_group: usiminas) }

      scenario 'removes the rate without costs' do
        visit tonnage_rates_path

        expect(page).to have_css("#tonnage_rate_#{tonnage_rate.id} a[data-turbo-confirm='Tem certeza que deseja excluir este custo?']")

        expect { page.driver.submit :delete, tonnage_rate_path(tonnage_rate), {} }.to change(TonnageRate, :count).by(-1)

        expect(page).to have_current_path(tonnage_rates_path)
        expect(page).to have_text('Custo excluído com sucesso.')
      end

      context 'when the rate was already calculated' do
        let!(:freight_expense) { create(:freight_expense, :tonnage, tenant:, tonnage_rate:) }

        scenario 'keeps the rate and explains why' do
          expect { page.driver.submit :delete, tonnage_rate_path(tonnage_rate), {} }.not_to change(TonnageRate, :count)

          expect(page).to have_current_path(tonnage_rates_path)
          expect(page).to have_text('Não é possível excluir um custo que já foi calculado nos CT-es. Desative o custo para deixar de usá-lo.')
        end
      end
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }
    let!(:tonnage_rate) { create(:tonnage_rate, tenant:, customer_group: usiminas) }

    before { login_as(operator, scope: :user) }

    context 'without access to the rates' do
      scenario 'is sent back with an access denied message' do
        visit tonnage_rates_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end

    context 'with read access to the rates' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'lists the rates without the management actions' do
        visit tonnage_rates_path

        expect(TonnageRate.count).to eq(1)
        expect(html_table_to_rows).to eq(
          [
            ['Origem', 'Nome', 'Grupo de clientes', 'Vigência', 'Média de', 'Valor por tonelada', 'Status', 'Ações'],
            ['Cubatão/SP (Cubatão)', 'Brasiltec', 'USIMINAS', '10/2026', '09/2026', 'R$ 12,57/t', 'Ativo', ''],
          ],
        )
        expect(page).to have_no_link('Novo Custo')

        click_on 'Cubatão/SP (Cubatão)'

        expect(page).to have_no_link('Alterar')
      end

      scenario 'cannot change a rate through a forged request' do
        page.driver.submit :patch, tonnage_rate_path(tonnage_rate), { tonnage_rate: { rate: '50' } }

        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
        expect(tonnage_rate.reload.rate_cents).to eq(1_257)
      end
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }
    let!(:tonnage_rate) { create(:tonnage_rate, tenant:, customer_group: usiminas) }

    before { login_as(admin, scope: :user) }

    scenario 'keeps the essential columns and collapses the actions into a menu' do
      visit tonnage_rates_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'ORIGEM')
      expect(page).to have_css('th', text: 'STATUS')
      expect(page).to have_no_css('th', text: 'GRUPO DE CLIENTES')
      expect(page).to have_no_css('th', text: 'VALOR POR TONELADA')

      within("#tonnage_rate_#{tonnage_rate.id}") do
        expect(page).to have_no_css('.inline-actions')
        click_button 'Opções'
        click_on 'Alterar'
      end

      expect(page).to have_current_path(edit_tonnage_rate_path(tonnage_rate))
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
