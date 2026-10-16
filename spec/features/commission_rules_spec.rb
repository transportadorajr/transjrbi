require 'rails_helper'

describe 'Commission rules' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Regras de comissão', slug: 'commission_rules') }
  let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS', terms: ['USIMINAS']) }

  context 'without a signed in user' do
    let!(:commission_rule) { create(:commission_rule, tenant:, customer_group: usiminas) }

    scenario 'redirects the listing to the login screen' do
      visit commission_rules_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'does not create a rule' do
      expect do
        page.driver.submit :post, commission_rules_path, { commission_rule: { name: 'Nacional' } }
      end.not_to change(CommissionRule, :count)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when an admin is signed in' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

    before { login_as(admin, scope: :user) }

    context 'when there are no rules' do
      scenario 'shows the empty state message' do
        visit commission_rules_path

        expect(CommissionRule.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_no_table
      end
    end

    context 'when there are rules' do
      let!(:national) { create(:commission_rule, tenant:, customer_group: usiminas) }
      let!(:argentina) { create(:commission_rule, :argentina, tenant:, customer_group: usiminas) }
      let!(:paraguay) { create(:commission_rule, :paraguay, tenant:, customer_group: usiminas, activated_at: nil) }
      let!(:stranger_rule) do
        create(:commission_rule, tenant: other_tenant, customer_group: create(:customer_group, tenant: other_tenant), name: 'REGRA DE OUTRA')
      end

      scenario 'lists the rules of the tenant from the registrations menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Cadastros'
          click_on 'Regras de comissão'
        end

        expect(page).to have_current_path(commission_rules_path)
        expect(CommissionRule.count).to eq(4)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Grupo de clientes', 'Destino', 'Base de cálculo', 'Comissão', 'Status', 'Ações'],
            ['Argentina', 'USIMINAS', 'Exterior (UF EX)', 'Frete bruto', '1,30%', 'Ativa', 'Opções Visualizar Alterar Excluir'],
            ['Nacional', 'USIMINAS', 'Nacional (qualquer UF brasileira)', 'Frete bruto sem ICMS', '2,00%', 'Ativa',
             'Opções Visualizar Alterar Excluir'],
            ['Paraguai', 'USIMINAS', 'Exterior (UF EX)', 'Frete bruto', '1,50%', 'Inativa', 'Opções Visualizar Alterar Excluir'],
          ],
        )
        expect(page).to have_css('.counter-card', text: "Total de regras\n3")
        expect(page).to have_css('.counter-card', text: "Regras ativas\n2")
        expect(page).to have_css('.counter-card', text: "Regras inativas\n1")
        expect(page).to have_link('Nova Regra', href: new_commission_rule_path)
        expect(page).to have_no_text('REGRA DE OUTRA')
      end

      scenario 'filters the rules by name, group and status' do
        visit commission_rules_path
        fill_in 'Nome da regra', with: 'para'
        select 'USIMINAS', from: 'Grupo de clientes'
        select 'Inativa', from: 'Status'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Grupo de clientes', 'Destino', 'Base de cálculo', 'Comissão', 'Status', 'Ações'],
            ['Paraguai', 'USIMINAS', 'Exterior (UF EX)', 'Frete bruto', '1,50%', 'Inativa', 'Opções Visualizar Alterar Excluir'],
          ],
        )
      end

      context 'when a rule has commissions' do
        let!(:first_expense) { create(:freight_expense, tenant:, commission_rule: argentina, amount_cents: 26_000) }
        let!(:second_expense) { create(:freight_expense, tenant:, commission_rule: argentina, amount_cents: 13_000) }

        scenario 'shows the rule with its commissions' do
          visit commission_rules_path
          click_on 'Argentina'

          expect(page).to have_current_path(commission_rule_path(argentina))
          expect(page).to have_css('h1.page-title', text: 'Argentina')
          expect(dl_to_hash('#commission_rule_data')).to eq(
            'Nome' => 'Argentina',
            'Grupo de clientes' => 'USIMINAS',
            'Destino' => 'Exterior (UF EX)',
            'Cidades de destino' => 'Buenos Aires, Puerto Iguazú, Rosario',
            'Base de cálculo' => 'Frete bruto',
            'Comissão' => '1,30%',
            'Status' => 'Ativa',
            'CT-es com comissão' => '2',
            'Total de comissões' => 'R$ 390,00',
          )
        end
      end

      scenario 'shows that a national rule serves any brazilian state' do
        visit commission_rule_path(national)

        expect(dl_to_hash('#commission_rule_data')).to include('Cidades de destino' => 'Qualquer UF brasileira')
      end

      scenario 'does not show a rule of another tenant' do
        visit commission_rule_path(stranger_rule)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when creating a rule' do
      scenario 'creates an active national rule and recalculates the commissions' do
        visit commission_rules_path
        click_on 'Nova Regra'
        select 'USIMINAS', from: 'Grupo de clientes'
        fill_in 'Nome', with: 'Nacional'
        select 'Nacional (qualquer UF brasileira)', from: 'Destino'
        select 'Frete bruto sem ICMS', from: 'Base de cálculo'
        fill_in 'Comissão (%)', with: '2'

        expect { click_on 'Cadastrar Regra' }.to change(CommissionRule, :count).by(1)
          .and have_enqueued_job(FreightExpenses::CalculateCommissionsJob).with(tenant.id)

        commission_rule = CommissionRule.last
        expect(page).to have_current_path(commission_rule_path(commission_rule))
        expect(page).to have_text('Regra cadastrada com sucesso. As comissões serão recalculadas em segundo plano.')
        expect(commission_rule).to have_attributes(tenant:, customer_group: usiminas, name: 'Nacional', destination_type: 'national',
                                                   base_type: 'freight_without_icms', percentage: BigDecimal('2'), cities: [])
        expect(commission_rule.activated_at).to be_present
      end

      scenario 'creates a foreign rule with its cities' do
        visit new_commission_rule_path
        select 'USIMINAS', from: 'Grupo de clientes'
        fill_in 'Nome', with: 'Paraguai'
        select 'Exterior (UF EX)', from: 'Destino'
        select 'Frete bruto', from: 'Base de cálculo'
        fill_in 'Comissão (%)', with: '1,5'
        fill_in 'Cidades de destino', with: "Asunción\nCiudad del Este"

        expect { click_on 'Cadastrar Regra' }.to change(CommissionRule, :count).by(1)

        expect(CommissionRule.last).to have_attributes(destination_type: 'foreign', base_type: 'freight', percentage: BigDecimal('1.5'),
                                                       cities: ['Asunción', 'Ciudad del Este'])
      end

      scenario 'shows the errors of the required fields' do
        visit new_commission_rule_path

        expect { click_on 'Cadastrar Regra' }.to not_change(CommissionRule, :count)
          .and not_have_enqueued_job(FreightExpenses::CalculateCommissionsJob)

        expect(page).to have_text('Grupo de clientes não pode ficar em branco')
        expect(page).to have_text('Comissão (%) deve ser maior que 0 e menor que 100')
      end

      context 'when the group already has an active national rule' do
        let!(:national) { create(:commission_rule, tenant:, customer_group: usiminas) }

        scenario 'shows the validation message' do
          visit new_commission_rule_path
          select 'USIMINAS', from: 'Grupo de clientes'
          fill_in 'Nome', with: 'Nacional nova'
          select 'Nacional (qualquer UF brasileira)', from: 'Destino'
          select 'Frete bruto', from: 'Base de cálculo'
          fill_in 'Comissão (%)', with: '3'

          expect { click_on 'Cadastrar Regra' }.not_to change(CommissionRule, :count)

          expect(page).to have_text('Destino nacional já tem outra regra ativa neste grupo')
        end
      end
    end

    context 'when editing a rule' do
      let!(:commission_rule) { create(:commission_rule, :argentina, tenant:, customer_group: usiminas) }

      scenario 'updates the rule and recalculates the commissions' do
        visit commission_rules_path
        within("#commission_rule_#{commission_rule.id} .inline-actions") { click_on 'Alterar' }

        expect(page).to have_current_path(edit_commission_rule_path(commission_rule))
        expect(page).to have_field('Comissão (%)', with: '1,3')
        expect(page).to have_field('Cidades de destino', with: "Buenos Aires\nPuerto Iguazú\nRosario")

        fill_in 'Comissão (%)', with: '1,35'
        fill_in 'Cidades de destino', with: "Buenos Aires\nRosario\nCórdoba"
        uncheck 'Ativa'

        expect { click_on 'Salvar Alterações' }.to not_change(CommissionRule, :count)
          .and have_enqueued_job(FreightExpenses::CalculateCommissionsJob).with(tenant.id)

        expect(page).to have_current_path(commission_rule_path(commission_rule))
        expect(page).to have_text('Regra atualizada com sucesso. As comissões serão recalculadas em segundo plano.')

        commission_rule.reload
        expect(commission_rule.percentage).to eq(BigDecimal('1.35'))
        expect(commission_rule.cities).to eq(['Buenos Aires', 'Rosario', 'Córdoba'])
        expect(commission_rule.activated_at).to be_nil
      end

      scenario 'shows the errors when the percentage is invalid' do
        visit edit_commission_rule_path(commission_rule)
        fill_in 'Comissão (%)', with: '0'
        click_on 'Salvar Alterações'

        expect(page).to have_text('Comissão (%) deve ser maior que 0 e menor que 100')
        expect(commission_rule.reload.percentage).to eq(BigDecimal('1.3'))
      end
    end

    context 'when removing a rule' do
      let!(:commission_rule) { create(:commission_rule, tenant:, customer_group: usiminas) }

      scenario 'removes the rule without commissions' do
        visit commission_rules_path

        expect(page).to have_css("#commission_rule_#{commission_rule.id} a[data-turbo-confirm='Tem certeza que deseja excluir esta regra?']")

        expect { page.driver.submit :delete, commission_rule_path(commission_rule), {} }.to change(CommissionRule, :count).by(-1)

        expect(page).to have_current_path(commission_rules_path)
        expect(page).to have_text('Regra excluída com sucesso.')
      end

      context 'when the rule already has commissions' do
        let!(:freight_expense) { create(:freight_expense, tenant:, commission_rule:) }

        scenario 'keeps the rule and explains why' do
          expect { page.driver.submit :delete, commission_rule_path(commission_rule), {} }.not_to change(CommissionRule, :count)

          expect(page).to have_current_path(commission_rules_path)
          expect(page).to have_text('Não é possível excluir uma regra que já gerou comissões. Desative a regra para deixar de usá-la.')
        end
      end
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }
    let!(:commission_rule) { create(:commission_rule, tenant:, customer_group: usiminas) }

    before { login_as(operator, scope: :user) }

    context 'without access to the rules' do
      scenario 'is sent back with an access denied message' do
        visit commission_rules_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end

    context 'with read access to the rules' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'lists the rules without the management actions' do
        visit commission_rules_path

        expect(CommissionRule.count).to eq(1)
        expect(html_table_to_rows).to eq(
          [
            ['Nome', 'Grupo de clientes', 'Destino', 'Base de cálculo', 'Comissão', 'Status', 'Ações'],
            ['Nacional', 'USIMINAS', 'Nacional (qualquer UF brasileira)', 'Frete bruto sem ICMS', '2,00%', 'Ativa', ''],
          ],
        )
        expect(page).to have_no_link('Nova Regra')

        click_on 'Nacional'

        expect(page).to have_no_link('Alterar')
      end

      scenario 'cannot change a rule through a forged request' do
        page.driver.submit :patch, commission_rule_path(commission_rule), { commission_rule: { percentage: '5' } }

        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
        expect(commission_rule.reload.percentage).to eq(BigDecimal('2'))
      end
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }
    let!(:commission_rule) { create(:commission_rule, tenant:, customer_group: usiminas) }

    before { login_as(admin, scope: :user) }

    scenario 'keeps the essential columns and collapses the actions into a menu' do
      visit commission_rules_path
      use_mobile_screen

      expect(page).to have_css('th', text: 'NOME')
      expect(page).to have_no_css('th', text: 'BASE DE CÁLCULO')

      within("#commission_rule_#{commission_rule.id}") do
        expect(page).to have_no_css('.inline-actions')
        click_button 'Opções'
        click_on 'Alterar'
      end

      expect(page).to have_current_path(edit_commission_rule_path(commission_rule))
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
