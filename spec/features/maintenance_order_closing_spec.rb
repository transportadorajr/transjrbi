require 'rails_helper'

describe 'Maintenance order closing', :maintenance, flipper: :maintenance do
  let!(:tenant) { create(:tenant) }
  let!(:resource) { create(:resource, name: 'Ordens de serviço', slug: 'maintenance_orders') }
  let!(:maintenance_resource) { create(:resource, name: 'Módulo de manutenção', slug: 'maintenance', writable: false) }
  let!(:maintenance_order) do
    create(:maintenance_order, tenant:, number: 7, plate: 'EXU1A23', odometer_km: 452_300, opened_at: Time.zone.local(2026, 11, 11, 8))
  end

  before { travel_to(Time.zone.local(2026, 11, 11, 17, 30)) }

  context 'when the owner is signed in' do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'starts the order, waits for a part and resumes it' do
      visit maintenance_order_path(maintenance_order)

      expect(page).to have_css('h1', text: 'OS 7 · EXU1A23')
      expect(page).to have_no_button('Retomar execução')

      click_on 'Iniciar execução'

      expect(page).to have_text('OS em execução.')
      expect(maintenance_order.reload.status_type).to eq('in_progress')
      expect(page).to have_no_button('Iniciar execução')

      click_on 'Aguardando peça'

      expect(page).to have_text('OS aguardando peça.')
      expect(maintenance_order.reload.status_type).to eq('waiting_parts')

      click_on 'Retomar execução'

      expect(page).to have_text('OS em execução.')
      expect(maintenance_order.reload.status_type).to eq('in_progress')
    end

    scenario 'finishes the order through the modal', :js do
      maintenance_order.update!(status_type: 'in_progress')

      visit maintenance_order_path(maintenance_order)
      click_on 'Encerrar OS'

      within('#maintenance_order_finish_modal') do
        expect(page).to have_field('Data e hora de conclusão', with: '2026-11-11T17:30')
        select 'Rodagem', from: 'Teste de liberação'
        fill_in 'Próxima preventiva (km)', with: '482300'
        fill_in 'Serviço executado', with: 'Troca das lonas e regulagem do freio'
        click_on 'Encerrar OS'
      end

      expect(page).to have_text('OS encerrada com sucesso.')
      expect(maintenance_order.reload).to have_attributes(status_type: 'finished', finished_at: Time.zone.local(2026, 11, 11, 17, 30),
                                                          release_test_type: 'road_test', next_preventive_km: 482_300,
                                                          performed_service: 'Troca das lonas e regulagem do freio')
      expect(dl_to_hash('#closing')).to eq('CONCLUSÃO' => '11/11/2026 17:30', 'TESTE DE LIBERAÇÃO' => 'Rodagem',
                                           'PRÓXIMA PREVENTIVA' => '482.300 km')
    end

    context 'when the order uses registered parts' do
      let!(:parts_resource) { create(:resource, name: 'Peças da manutenção', slug: 'maintenance_parts') }
      let!(:lining) { create(:maintenance_part, tenant:, description: 'LONA DE FREIO', unit: 'UN', quantity: 10) }
      let!(:oil) { create(:maintenance_part, tenant:, description: 'ÓLEO 15W40', unit: 'L', quantity: 5) }
      let!(:stock_part) { create(:maintenance_order_part, maintenance_order:, maintenance_part: lining, quantity: 4, source_type: :stock) }
      let!(:purchased_part) do
        create(:maintenance_order_part, maintenance_order:, maintenance_part: lining, quantity: 2, source_type: :purchase)
      end
      let!(:short_part) { create(:maintenance_order_part, maintenance_order:, maintenance_part: oil, quantity: 8, source_type: :stock) }
      let!(:free_part) { create(:maintenance_order_part, maintenance_order:, description: 'PARAFUSO', quantity: 6, source_type: :stock) }

      scenario 'takes the stock parts out of the stock when the order is finished' do
        page.driver.submit :patch, finish_maintenance_order_path(maintenance_order),
                           { maintenance_order_finish: { finished_at: '2026-11-11T17:30', release_test_type: 'road_test',
                                                         performed_service: 'Troca das lonas' } }

        expect(maintenance_order.reload).to be_finished
        expect(MaintenancePartMovement.count).to eq(2)
        expect(lining.reload.quantity).to eq(6)
        expect(oil.reload.quantity).to eq(-3)
        expect(stock_part.stock_movement).to have_attributes(movement_type: 'exit', quantity: -4, balance: 6, maintenance_order:,
                                                             moved_on: Date.new(2026, 11, 11), created_by: owner)

        visit maintenance_part_movements_path

        expect(html_table_to_rows).to eq(
          [
            ['Data', 'Peça', 'Tipo', 'Quantidade', 'Saldo', 'Origem', 'Responsável'],
            ['11/11/2026', 'ÓLEO 15W40', 'Saída', '-8 L', '-3 L', 'OS nº 7', owner.name],
            ['11/11/2026', 'LONA DE FREIO', 'Saída', '-4 UN', '6 UN', 'OS nº 7', owner.name],
          ],
        )
      end
    end

    scenario 'keeps the finish modal open with the errors', :js do
      visit maintenance_order_path(maintenance_order)
      click_on 'Encerrar OS'

      within('#maintenance_order_finish_modal') do
        fill_in 'Próxima preventiva (km)', with: '400000'
        click_on 'Encerrar OS'

        expect(page).to have_css('.alert-danger', text: 'Teste de liberação não pode ficar em branco')
        expect(page).to have_text('Próxima preventiva (km) deve ser maior que o KM da abertura')
      end

      expect(maintenance_order.reload.status_type).to eq('open')
    end

    scenario 'opens the finish modal through a turbo stream' do
      visit finishing_maintenance_order_path(maintenance_order, format: :turbo_stream)

      expect(page.status_code).to eq(200)
      expect(page.body).to include('turbo-stream action="update" target="remote-container"')
      expect(page.body).to include('Encerrar Ordem de Serviço')
    end

    scenario 'cancels the order' do
      visit maintenance_order_path(maintenance_order)
      click_on 'Cancelar OS'

      expect(page).to have_text('OS cancelada.')
      expect(maintenance_order.reload.status_type).to eq('cancelled')
      expect(page).to have_no_button('Cancelar OS')
      expect(page).to have_no_link('Encerrar OS')
    end

    context 'when the order is finished' do
      let!(:part) { create(:maintenance_order_part, maintenance_order:) }

      before do
        maintenance_order.update!(status_type: 'finished', finished_at: Time.zone.local(2026, 11, 11, 16), release_test_type: 'yard_test')
      end

      scenario 'shows the closing data without any option to change the order' do
        visit maintenance_order_path(maintenance_order)

        expect(dl_to_hash('#closing')).to eq('Conclusão' => '11/11/2026 16:00', 'Teste de liberação' => 'Funcionamento em pátio',
                                             'Próxima preventiva' => '-')
        within('.page-shell') do
          expect(page).to have_no_link('Alterar')
          expect(page).to have_no_link('Adicionar peça')
          expect(page).to have_no_link('Encerrar OS')
          expect(page).to have_no_button('Iniciar execução')
          expect(page).to have_no_button('Cancelar OS')
          expect(page).to have_no_link('Excluir')
        end
      end

      scenario 'does not open the edit screen' do
        visit edit_maintenance_order_path(maintenance_order)

        expect(page).to have_current_path(maintenance_order_path(maintenance_order))
        expect(page).to have_text('Esta OS já foi encerrada e não pode mais ser alterada.')
      end

      scenario 'does not change the items nor the status' do
        expect do
          page.driver.submit :post, maintenance_order_parts_path(maintenance_order),
                             { maintenance_order_part: { description: 'FILTRO', quantity: '1' } }
        end.not_to change(MaintenanceOrderPart, :count)

        expect(page).to have_text('Esta OS já foi encerrada e não pode mais ser alterada.')

        expect do
          page.driver.submit :delete, maintenance_order_part_path(maintenance_order, part), {}
        end.not_to change(MaintenanceOrderPart, :count)

        page.driver.submit :patch, cancel_maintenance_order_path(maintenance_order), {}

        expect(page).to have_text('A OS não pode mudar de situação porque está concluída.')
        expect(maintenance_order.reload.status_type).to eq('finished')
      end

      scenario 'does not finish the order again' do
        page.driver.submit :patch, finish_maintenance_order_path(maintenance_order),
                           { maintenance_order_finish: { finished_at: '2026-11-11T17:00', release_test_type: 'road_test',
                                                         performed_service: 'Outro' } }

        expect(page).to have_text('Esta OS já foi encerrada e não pode mais ser alterada.')
        expect(maintenance_order.reload).to have_attributes(finished_at: Time.zone.local(2026, 11, 11, 16), release_test_type: 'yard_test')
      end
    end
  end

  context 'when the signatures are required', flipper: %i[maintenance maintenance_order_signatures] do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }
    let!(:supervisor) { create(:workshop_employee, tenant:, name: 'PAULO LIMA', role_type: 'supervisor') }
    let!(:carlos) { create(:workshop_employee, tenant:, name: 'CARLOS SOUZA') }
    let!(:ana) { create(:workshop_employee, tenant:, name: 'ANA COSTA') }
    let!(:carlos_labor) { create(:maintenance_order_labor, maintenance_order:, workshop_employee: carlos) }
    let!(:ana_labor) { create(:maintenance_order_labor, maintenance_order:, workshop_employee: ana) }

    before do
      maintenance_order.update!(status_type: 'in_progress', supervisor:)
      login_as(owner, scope: :user)
    end

    scenario 'finishes the order with the signature of the supervisor and of each mechanic', :js do
      visit maintenance_order_path(maintenance_order)
      click_on 'Encerrar OS'

      within('#maintenance_order_finish_modal') do
        expect(page).to have_select('Encarregado', selected: 'PAULO LIMA')
        expect(page).to have_css('label', text: 'Assinatura do encarregado')
        expect(page).to have_css('label', text: 'ANA COSTA · Mecânico')
        expect(page).to have_css('label', text: 'CARLOS SOUZA · Mecânico')

        select 'Rodagem', from: 'Teste de liberação'
        fill_in 'Serviço executado', with: 'Troca das lonas'
      end

      draw_signature('supervisor_signature')
      draw_signature("mechanic_signature_#{carlos.id}")
      draw_signature("mechanic_signature_#{ana.id}")

      expect do
        within('#maintenance_order_finish_modal') { click_on 'Encerrar OS' }

        expect(page).to have_text('OS encerrada com sucesso.')
      end.to change(MaintenanceOrderSignature, :count).by(3)

      expect(maintenance_order.reload.status_type).to eq('finished')
      signatures = maintenance_order.signatures.order(:signer_role_type, :signer_name)
      expect(signatures.map { |signature| [signature.signer_role_type, signature.signer_name] })
        .to eq([['supervisor', 'PAULO LIMA'], ['mechanic', 'ANA COSTA'], ['mechanic', 'CARLOS SOUZA']])
      expect(signatures).to all(have_attributes(signed_by: owner, content_digest: maintenance_order.content_digest))
      expect(signatures.map { |signature| MaintenanceOrderSignature.drawn?(signature.strokes) }).to all(be(true))

      expect(page).to have_css('#signatures img.signature-image', count: 3)
      signatures.each do |signature|
        expect(page).to have_css("img[alt='Assinatura de #{signature.signer_name}']")
        expect(dl_to_hash("#maintenance_order_signature_#{signature.id}"))
          .to eq('NOME' => signature.signer_name, 'FUNÇÃO' => signature.signer_role_type_name, 'ASSINADA EM' => '11/11/2026 17:30')
      end
      expect(dl_to_hash('#signature_verification')).to eq('CÓDIGO DE VERIFICAÇÃO' => maintenance_order.content_digest)
    end

    scenario 'keeps the modal open while a mechanic has not signed', :js do
      visit maintenance_order_path(maintenance_order)
      click_on 'Encerrar OS'

      within('#maintenance_order_finish_modal') do
        select 'Rodagem', from: 'Teste de liberação'
        fill_in 'Serviço executado', with: 'Troca das lonas'
      end

      draw_signature('supervisor_signature')
      draw_signature("mechanic_signature_#{carlos.id}")

      within('#maintenance_order_finish_modal') do
        click_on 'Encerrar OS'

        expect(page).to have_css('.alert-danger', text: 'Falta a assinatura de ANA COSTA.')
        expect(page).to have_css('.signature-pad-signed', count: 2)
      end

      expect(maintenance_order.reload.status_type).to eq('in_progress')
      expect(MaintenanceOrderSignature.count).to eq(0)
    end

    scenario 'signs on a phone without scrolling sideways', :js do
      visit maintenance_order_path(maintenance_order)
      use_mobile_screen
      click_on 'Encerrar OS'

      within('#maintenance_order_finish_modal') do
        select 'Funcionamento em pátio', from: 'Teste de liberação'
        fill_in 'Serviço executado', with: 'Troca das lonas'
      end

      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
      expect(page.evaluate_script("getComputedStyle(document.getElementById('supervisor_signature')).touchAction")).to eq('none')

      draw_signature('supervisor_signature')
      draw_signature("mechanic_signature_#{carlos.id}")
      draw_signature("mechanic_signature_#{ana.id}")
      within('#maintenance_order_finish_modal') { click_on 'Encerrar OS' }

      expect(page).to have_text('OS encerrada com sucesso.')
      expect(maintenance_order.signatures.count).to eq(3)
    end

    scenario 'does not finish the order with a forged signature' do
      page.driver.submit :patch, finish_maintenance_order_path(maintenance_order),
                         { maintenance_order_finish: { finished_at: '2026-11-11T17:30', release_test_type: 'road_test',
                                                       performed_service: 'Troca', supervisor_id: supervisor.id,
                                                       supervisor_signature: '<svg onload="alert(1)"/>',
                                                       mechanic_signatures: { carlos.id => signature_strokes, ana.id => signature_strokes } } }

      expect(page.status_code).to eq(422)
      expect(maintenance_order.reload.status_type).to eq('in_progress')
      expect(MaintenanceOrderSignature.count).to eq(0)
    end
  end

  context 'when a user can only read the maintenance orders' do
    let!(:reader) { create(:user, tenant:) }
    let!(:access) { create(:access, user: reader, resource:, reads: true, creates: false) }
    let!(:maintenance_access) { create(:access, user: reader, resource: maintenance_resource, creates: false) }

    before { login_as(reader, scope: :user) }

    scenario 'sees no status option and cannot change the status' do
      visit maintenance_order_path(maintenance_order)

      expect(page).to have_css('h1', text: 'OS 7 · EXU1A23')
      expect(page).to have_no_button('Iniciar execução')
      expect(page).to have_no_link('Encerrar OS')

      page.driver.submit :patch, start_maintenance_order_path(maintenance_order), {}

      expect(maintenance_order.reload.status_type).to eq('open')
    end
  end

  context 'when the screen is opened on a phone', :js do
    let!(:owner) { create(:user, tenant:, user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'wraps the status buttons without scrolling sideways' do
      visit maintenance_order_path(maintenance_order)
      use_mobile_screen

      expect(page).to have_button('Iniciar execução')
      expect(page).to have_link('Encerrar OS')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)
    end
  end
end
