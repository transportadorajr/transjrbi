require 'rails_helper'

describe 'Product groups' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'Grupos de produtos', slug: 'product_groups') }

  context 'without a signed in user' do
    let!(:product_group) { create(:product_group, tenant:) }

    scenario 'redirects the listing to the login screen' do
      visit product_groups_path

      expect(page).to have_current_path(new_user_session_path)
    end

    scenario 'does not create a group' do
      expect do
        page.driver.submit :post, product_groups_path, { product_group: { name: 'SIDERÚRGICO' } }
      end.not_to change(ProductGroup, :count)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when an admin is signed in' do
    let!(:admin) { create(:user, tenant:, name: 'Bruna Admin', user_type: :admin) }

    before { login_as(admin, scope: :user) }

    context 'when there are no groups' do
      let!(:document) { create(:atua_transport_document, tenant:, product_name: 'BOBINA') }

      scenario 'shows the empty state and the products without a group' do
        visit product_groups_path

        expect(ProductGroup.count).to eq(0)
        expect(page).to have_text('Nenhum registro encontrado')
        expect(page).to have_css('.counter-card', text: "Produtos sem grupo\n1")
        expect(html_table_to_rows(table: find_by_id('unclassified_products'))).to eq(
          [
            %w[Produto CT-es],
            %w[BOBINA 1],
          ],
        )
      end
    end

    context 'when there are groups' do
      let!(:steel) { create(:product_group, tenant:, name: 'SIDERÚRGICO') }
      let!(:food) { create(:product_group, tenant:, name: 'ALIMENTÍCIO', activated_at: nil) }
      let!(:coil) { create(:product_subgroup, tenant:, parent: steel, name: 'BOBINA', product_names: ['BOBINA']) }
      let!(:rebar) { create(:product_subgroup, tenant:, parent: steel, name: 'VERGALHÃO', product_names: ['VERGALHAO DE FERRO'], activated_at: nil) }
      let!(:stranger_group) { create(:product_group, tenant: other_tenant, name: 'GRUPO DE OUTRA EMPRESA') }
      let!(:coil_documents) { create_list(:atua_transport_document, 2, tenant:, product_name: 'BOBINA', product_group: coil) }
      let!(:rebar_document) { create(:atua_transport_document, tenant:, product_name: 'VERGALHAO DE FERRO') }
      let!(:mixed_document) { create(:atua_transport_document, tenant:, product_name: 'DIVERSOS') }

      scenario 'lists the groups of the tenant from the registrations menu' do
        visit root_path
        within('.sidebar-desktop') do
          click_on 'Cadastros'
          click_on 'Grupos de produtos'
        end

        expect(page).to have_current_path(product_groups_path)
        expect(ProductGroup.groups.count).to eq(3)
        expect(html_table_to_rows(table: find_by_id('product_groups'))).to eq(
          [
            ['Nome', 'Subgrupos', 'CT-es', 'Status', 'Ações'],
            ['ALIMENTÍCIO', '0', '0', 'Inativo', 'Opções Visualizar Alterar Excluir'],
            ['SIDERÚRGICO', '2', '2', 'Ativo', 'Opções Visualizar Alterar Excluir'],
          ],
        )
        expect(html_table_to_rows(table: find_by_id('unclassified_products'))).to eq(
          [
            ['Produto', 'CT-es'],
            %w[DIVERSOS 1],
            ['VERGALHAO DE FERRO', '1'],
          ],
        )
        expect(page).to have_css('.counter-card', text: "Total de grupos\n2")
        expect(page).to have_css('.counter-card', text: "Grupos ativos\n1")
        expect(page).to have_css('.counter-card', text: "Grupos inativos\n1")
        expect(page).to have_css('.counter-card', text: "Produtos sem grupo\n2")
        expect(page).to have_link('Novo Grupo', href: new_product_group_path)
        expect(page).to have_no_text('GRUPO DE OUTRA EMPRESA')
      end

      scenario 'filters the groups by name and status' do
        visit product_groups_path
        fill_in 'Nome do grupo', with: 'sider'
        select 'Ativo', from: 'Status'
        click_on 'Aplicar Filtros'

        expect(html_table_to_rows(table: find_by_id('product_groups'))).to eq(
          [
            ['Nome', 'Subgrupos', 'CT-es', 'Status', 'Ações'],
            ['SIDERÚRGICO', '2', '2', 'Ativo', 'Opções Visualizar Alterar Excluir'],
          ],
        )
      end

      scenario 'shows the group with its subgroups' do
        visit product_groups_path
        click_on 'SIDERÚRGICO'

        expect(page).to have_current_path(product_group_path(steel))
        expect(page).to have_css('h1.page-title', text: 'SIDERÚRGICO')
        expect(dl_to_hash('#product_group_data')).to eq(
          'Nome' => 'SIDERÚRGICO',
          'Status' => 'Ativo',
          'Subgrupos' => '2',
          'CT-es' => '2',
        )
        expect(html_table_to_rows(table: find_by_id('product_subgroups'))).to eq(
          [
            ['Nome', 'Produtos', 'CT-es', 'Status', 'Ações'],
            ['BOBINA', 'BOBINA', '2', 'Ativo', 'Opções Visualizar Alterar Excluir'],
            ['VERGALHÃO', 'VERGALHAO DE FERRO', '0', 'Inativo', 'Opções Visualizar Alterar Excluir'],
          ],
        )
        expect(page).to have_link('Novo Subgrupo', href: new_product_group_path(parent_id: steel.id))
      end

      scenario 'shows the subgroup with its products' do
        visit product_group_path(steel)
        click_on 'BOBINA'

        expect(page).to have_current_path(product_group_path(coil))
        expect(dl_to_hash('#product_group_data')).to eq(
          'Nome' => 'BOBINA',
          'Grupo' => 'SIDERÚRGICO',
          'Status' => 'Ativo',
          'Produtos' => 'BOBINA',
          'CT-es' => '2',
        )
        expect(html_table_to_rows(table: find_by_id('product_group_products'))).to eq(
          [
            %w[Produto CT-es],
            %w[BOBINA 2],
          ],
        )
        expect(page).to have_no_link('Novo Subgrupo')
      end

      scenario 'does not show a group of another tenant' do
        visit product_group_path(stranger_group)

        expect(page.status_code).to eq(404)
      end
    end

    context 'when creating a group' do
      scenario 'creates an active group' do
        visit product_groups_path
        click_on 'Novo Grupo'
        fill_in 'Nome', with: ' SIDERÚRGICO '

        expect(page).to have_no_field('Produtos')
        expect { click_on 'Cadastrar' }.to change(ProductGroup, :count).by(1)

        product_group = ProductGroup.last
        expect(page).to have_current_path(product_group_path(product_group))
        expect(page).to have_text('Grupo cadastrado com sucesso.')
        expect(product_group.tenant).to eq(tenant)
        expect(product_group.name).to eq('SIDERÚRGICO')
        expect(product_group.parent).to be_nil
        expect(product_group.product_names).to eq([])
        expect(product_group.activated_at).to be_present
      end

      scenario 'shows the errors of the required fields' do
        visit new_product_group_path

        expect { click_on 'Cadastrar' }.not_to change(ProductGroup, :count)

        expect(page).to have_text('Nome não pode ficar em branco')
      end

      context 'when the name is already taken' do
        let!(:existing_group) { create(:product_group, tenant:, name: 'SIDERÚRGICO') }

        scenario 'shows the validation message' do
          visit new_product_group_path
          fill_in 'Nome', with: 'SIDERÚRGICO'

          expect { click_on 'Cadastrar' }.not_to change(ProductGroup, :count)

          expect(page).to have_text('Nome já está em uso por outro grupo')
        end
      end
    end

    context 'when creating a subgroup' do
      let!(:steel) { create(:product_group, tenant:, name: 'SIDERÚRGICO') }
      let!(:wire) { create(:product_subgroup, tenant:, parent: steel, name: 'FIO MÁQUINA', product_names: ['FIO MAQUINA']) }
      let!(:coil_documents) { create_list(:atua_transport_document, 2, tenant:, product_name: 'BOBINA') }
      let!(:sheet_document) { create(:atua_transport_document, tenant:, product_name: 'CHAPAS') }
      let!(:wire_document) { create(:atua_transport_document, tenant:, product_name: 'FIO MAQUINA', product_group: wire) }
      let!(:stranger_document) { create(:atua_transport_document, tenant: other_tenant, product_name: 'TUBO INOX') }

      scenario 'searches the products and creates the subgroup with the chosen ones classifying their transport documents', :js do
        visit product_group_path(steel)
        click_on 'Novo Subgrupo'

        expect(page).to have_current_path(new_product_group_path(parent_id: steel.id))
        fill_in 'Nome', with: 'BOBINA'

        within('#product_names_select') do
          expect(page).to have_css('.select2-placeholder', text: 'Selecione os produtos')

          find('.select2-trigger').click
          expect(all('.select2-option').map(&:text)).to eq(['BOBINA (2 CT-es)', 'CHAPAS (1 CT-es)'])

          find('.select2-search').fill_in(with: 'bob')
          expect(all('.select2-option').map(&:text)).to eq(['BOBINA (2 CT-es)'])
          find('.select2-option', text: 'BOBINA').click

          find('.select2-search').fill_in(with: 'chap')
          find('.select2-option', text: 'CHAPAS').click

          expect(all('.select2-tag__label').map(&:text)).to eq(['BOBINA (2 CT-es)', 'CHAPAS (1 CT-es)'])
        end

        click_on 'Cadastrar'

        expect(page).to have_text('Grupo cadastrado com sucesso.')
        expect(page).to have_current_path(product_group_path(steel))
        expect(ProductGroup.count).to eq(3)

        subgroup = ProductGroup.last
        expect(subgroup.tenant).to eq(tenant)
        expect(subgroup.parent).to eq(steel)
        expect(subgroup.name).to eq('BOBINA')
        expect(subgroup.product_names).to eq(%w[BOBINA CHAPAS])
        expect(subgroup.activated_at).to be_present
        expect(Atua::TransportDocument.where(product_group: subgroup)).to contain_exactly(*coil_documents, sheet_document)
        expect(wire_document.reload.product_group).to eq(wire)
        expect(stranger_document.reload.product_group).to be_nil
      end

      scenario 'does not create a subgroup inside another subgroup' do
        visit new_product_group_path(parent_id: wire.id)

        expect(page.status_code).to eq(404)
      end

      scenario 'does not take a product already in another subgroup through a forged request' do
        expect do
          page.driver.submit :post, product_groups_path,
                             { product_group: { name: 'OUTRO FIO', parent_id: steel.id, product_names: ['FIO MAQUINA'] } }
        end.not_to change(ProductGroup, :count)

        expect(page).to have_text('Produtos FIO MAQUINA já estão em outro subgrupo')
      end
    end

    context 'when editing a subgroup' do
      let!(:steel) { create(:product_group, tenant:, name: 'SIDERÚRGICO') }
      let!(:coil) { create(:product_subgroup, tenant:, parent: steel, name: 'BOBINA', product_names: %w[BOBINA CHAPAS]) }
      let!(:coil_document) { create(:atua_transport_document, tenant:, product_name: 'BOBINA', product_group: coil) }
      let!(:sheet_document) { create(:atua_transport_document, tenant:, product_name: 'CHAPAS', product_group: coil) }

      scenario 'keeps the products selected and moves the removed ones out of the subgroup', :js do
        visit product_group_path(steel)
        within("#product_group_#{coil.id} .inline-actions") { click_on 'Alterar' }

        expect(page).to have_current_path(edit_product_group_path(coil))
        within('#product_names_select') do
          expect(all('.select2-tag__label').map(&:text)).to eq(['BOBINA (1 CT-es)', 'CHAPAS (1 CT-es)'])

          find('.select2-tag', text: 'CHAPAS').find('.select2-tag__remove').click

          expect(all('.select2-tag__label').map(&:text)).to eq(['BOBINA (1 CT-es)'])
        end

        fill_in 'Nome', with: 'BOBINAS'
        click_on 'Salvar Alterações'

        expect(page).to have_text('Grupo atualizado com sucesso.')
        expect(page).to have_current_path(product_group_path(coil))
        expect(ProductGroup.count).to eq(2)

        coil.reload
        expect(coil.name).to eq('BOBINAS')
        expect(coil.parent).to eq(steel)
        expect(coil.product_names).to eq(['BOBINA'])
        expect(coil_document.reload.product_group).to eq(coil)
        expect(sheet_document.reload.product_group).to be_nil
      end

      scenario 'keeps the products of the subgroup when it is saved without touching them' do
        visit edit_product_group_path(coil)
        click_on 'Salvar Alterações'

        expect(page).to have_text('Grupo atualizado com sucesso.')
        expect(coil.reload.product_names).to eq(%w[BOBINA CHAPAS])
      end

      scenario 'removes the transport documents from the group when it is deactivated' do
        visit edit_product_group_path(steel)
        uncheck 'Ativo'
        click_on 'Salvar Alterações'

        expect(page).to have_text('Grupo atualizado com sucesso.')
        expect(steel.reload.activated_at).to be_nil
        expect(Atua::TransportDocument.where.not(product_group_id: nil).count).to eq(0)
      end

      scenario 'shows the errors when the name is removed' do
        visit edit_product_group_path(coil)
        fill_in 'Nome', with: ''
        click_on 'Salvar Alterações'

        expect(page).to have_text('Nome não pode ficar em branco')
        expect(coil.reload.name).to eq('BOBINA')
      end
    end

    context 'when removing a group' do
      let!(:steel) { create(:product_group, tenant:, name: 'SIDERÚRGICO') }
      let!(:coil) { create(:product_subgroup, tenant:, parent: steel, name: 'BOBINA', product_names: ['BOBINA']) }
      let!(:coil_document) { create(:atua_transport_document, tenant:, product_name: 'BOBINA', product_group: coil) }

      scenario 'removes a subgroup and leaves its transport documents without a group' do
        visit product_group_path(steel)

        expect(page).to have_css("#product_group_#{coil.id} a[data-turbo-confirm='Tem certeza que deseja excluir este grupo?']")

        expect { page.driver.submit :delete, product_group_path(coil), {} }.to change(ProductGroup, :count).by(-1)

        expect(page).to have_current_path(product_group_path(steel))
        expect(page).to have_text('Grupo excluído com sucesso.')
        expect(coil_document.reload.product_group).to be_nil
      end

      scenario 'keeps a group with subgroups and explains why' do
        expect { page.driver.submit :delete, product_group_path(steel), {} }.not_to change(ProductGroup, :count)

        expect(page).to have_current_path(product_groups_path)
        expect(page).to have_text('Não é possível excluir um grupo com subgrupos. Exclua os subgrupos ou desative o grupo para deixar de usá-lo.')
      end
    end
  end

  context 'when an operator is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }
    let!(:product_group) { create(:product_group, tenant:, name: 'SIDERÚRGICO') }

    before { login_as(operator, scope: :user) }

    context 'without access to the groups' do
      scenario 'is sent back with an access denied message' do
        visit product_groups_path

        expect(page).to have_current_path(root_path)
        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end

    context 'with read access to the groups' do
      let!(:access) { create(:access, user: operator, resource:, reads: true) }

      scenario 'lists the groups without the management actions' do
        visit product_groups_path

        expect(ProductGroup.count).to eq(1)
        expect(html_table_to_rows(table: find_by_id('product_groups'))).to eq(
          [
            ['Nome', 'Subgrupos', 'CT-es', 'Status', 'Ações'],
            ['SIDERÚRGICO', '0', '0', 'Ativo', ''],
          ],
        )
        expect(page).to have_no_link('Novo Grupo')

        click_on 'SIDERÚRGICO'

        expect(page).to have_no_link('Alterar')
        expect(page).to have_no_link('Novo Subgrupo')
      end

      scenario 'cannot remove a group through a forged request' do
        expect { page.driver.submit :delete, product_group_path(product_group), {} }.not_to change(ProductGroup, :count)

        expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      end
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:admin) { create(:user, tenant:, user_type: :admin) }
    let!(:product_group) { create(:product_group, tenant:, name: 'SIDERÚRGICO') }

    before { login_as(admin, scope: :user) }

    scenario 'keeps the essential columns and collapses the actions into a menu' do
      visit product_groups_path
      use_mobile_screen

      expect(page).to have_css('#product_groups th', text: 'NOME')
      expect(page).to have_no_css('#product_groups th', text: 'SUBGRUPOS')

      within("#product_group_#{product_group.id}") do
        expect(page).to have_no_css('.inline-actions')
        click_button 'Opções'
        click_on 'Alterar'
      end

      expect(page).to have_current_path(edit_product_group_path(product_group))
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
