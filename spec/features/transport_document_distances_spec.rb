require 'rails_helper'

describe 'Transport document distance' do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:resource) { create(:resource, name: 'CT-es', slug: 'transport_documents', writable: false) }
  let!(:transport_document) do
    create(:atua_transport_document, tenant:, number: '74130', taker_code: 7001, origin_city: 'IPATINGA', origin_state: 'MG',
                                     destination_city: 'BETIM', destination_state: 'MG', distance_km: BigDecimal('230.5'))
  end

  context 'without a signed in user' do
    scenario 'redirects to the login screen' do
      visit edit_transport_document_distance_path(transport_document)

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'when the owner is signed in' do
    let!(:owner) { create(:user, tenant:, name: 'Bruna Dona', user_type: :owner) }

    before { login_as(owner, scope: :user) }

    scenario 'changes the distance of the transport document' do
      visit transport_document_path(transport_document)
      click_on 'Alterar KM'

      expect(page).to have_current_path(edit_transport_document_distance_path(transport_document))
      expect(page).to have_css('h1.page-title', text: 'Alterar KM do CT-e 74130')
      expect(page).to have_text('KM do Atua: 230,50.')

      fill_in 'KM considerado', with: '1.250,5'
      expect { click_on 'Salvar KM' }.not_to change(Atua::TransportDocument, :count)

      expect(page).to have_current_path(transport_document_path(transport_document))
      expect(page).to have_text('KM do CT-e atualizado.')
      expect(dl_to_hash('#transport')).to include('Distância (km)' => '1.250,50 KM alterado neste CT-e. KM do Atua: 230,50')
      expect(transport_document.reload).to have_attributes(distance_km: BigDecimal('1250.5'), original_distance_km: BigDecimal('230.5'))
      expect(transport_document.distance_edited_at).to be_present
    end

    scenario 'changes the distance on a phone', :js do
      use_mobile_screen
      visit transport_document_path(transport_document)
      click_on 'Alterar KM'

      fill_in 'KM considerado', with: '300'
      click_on 'Salvar KM'

      expect(page).to have_text('KM do CT-e atualizado.')
      expect(transport_document.reload.distance_km).to eq(BigDecimal('300'))
    end

    scenario 'shows the error of an invalid distance' do
      visit edit_transport_document_distance_path(transport_document)

      fill_in 'KM considerado', with: '0'
      click_on 'Salvar KM'

      expect(page).to have_text('KM considerado deve ser maior que 0')
      expect(transport_document.reload).to have_attributes(distance_km: BigDecimal('230.5'), distance_edited_at: nil)
    end

    context 'when the distance was edited and the route has a registered distance' do
      let!(:route_distance) do
        create(:route_distance, tenant:, customer_code: 7001, origin_city: 'IPATINGA', origin_state: 'MG', destination_city: 'BETIM',
                                destination_state: 'MG', distance_km: BigDecimal('240'))
      end

      before { TransportDocuments::UpdateDistanceCommand.call(transport_document, BigDecimal('250')) }

      scenario 'goes back to the distance of the route when the distance is cleared' do
        visit edit_transport_document_distance_path(transport_document)

        expect(page).to have_field('KM considerado', with: '250,00')

        fill_in 'KM considerado', with: ''
        click_on 'Salvar KM'

        expect(page).to have_text('KM do CT-e atualizado.')
        expect(dl_to_hash('#transport')).to include('Distância (km)' => '240,00 KM do trecho cadastrado. KM do Atua: 230,50')
        expect(transport_document.reload).to have_attributes(distance_km: BigDecimal('240'), route_distance_id: route_distance.id,
                                                             distance_edited_at: nil)
      end
    end

    context 'when the document is a CE' do
      let!(:ce) { create(:atua_transport_document, tenant:, number: '4526', document_kind: 'ce', distance_km: BigDecimal('120')) }

      scenario 'names the document as a CE on the distance change title' do
        visit edit_transport_document_distance_path(ce)

        expect(page).to have_css('h1.page-title', text: 'Alterar KM do CE 4526')
        expect(page).to have_title('Alterar KM do CE 4526')
      end
    end

    scenario 'cannot change the distance of a transport document of another tenant' do
      stranger = create(:atua_transport_document, tenant: other_tenant, distance_km: BigDecimal('100'))

      page.driver.submit :patch, transport_document_distance_path(stranger), { transport_document_distance: { distance_km: '500' } }

      expect(page.status_code).to eq(404)
      expect(stranger.reload.distance_km).to eq(BigDecimal('100'))
    end
  end

  context 'when an operator with read access is signed in' do
    let!(:operator) { create(:user, tenant:, name: 'Carla Operadora') }
    let!(:access) { create(:access, user: operator, resource:, reads: true) }

    before { login_as(operator, scope: :user) }

    scenario 'does not offer the distance change' do
      visit transport_document_path(transport_document)

      expect(page).to have_css('h1.page-title', text: 'CT-e 74130')
      expect(page).to have_no_link('Alterar KM')
    end

    scenario 'cannot change the distance through a forged request' do
      page.driver.submit :patch, transport_document_distance_path(transport_document), { transport_document_distance: { distance_km: '500' } }

      expect(page).to have_text('Você não possui acesso a esta funcionalidade.')
      expect(transport_document.reload).to have_attributes(distance_km: BigDecimal('230.5'), distance_edited_at: nil)
    end
  end
end
