require 'rails_helper'

RSpec.describe Atua::ImportMailer do
  describe '#repeated_failures' do
    let!(:tenant) { create(:tenant, trade_name: 'TransJR') }
    let!(:admin_users) { [create(:admin_user, email: 'marina@transjrbi.com.br'), create(:admin_user, email: 'bruno@transjrbi.com.br')] }
    let!(:import) do
      create(:atua_import, tenant:, report_type: 'transport_documents', status_type: 'failed', error_type: 'authentication',
                           error_message: 'A Atua recusou o login, a resposta ainda contém o formulário de login.')
    end

    it 'warns every admin user about the repeated failures' do
      mail = described_class.repeated_failures(import)

      expect { mail.deliver_now }.to change(ActionMailer::Base.deliveries, :count).by(1)
      expect(mail.to).to eq(%w[bruno@transjrbi.com.br marina@transjrbi.com.br])
      expect(mail.subject).to eq('Atua: importação de Conhecimentos de transporte da TransJR falhou seguidamente')
      expect(mail.body.encoded).to include('A importação de Conhecimentos de transporte da TransJR falhou 3 vezes seguidas.')
      expect(mail.body.encoded).to include('Login na Atua: A Atua recusou o login, a resposta ainda contém o formulário de login.')
      expect(mail.body.encoded).to include("http://admin.localhost/imports?report_type=transport_documents&amp;tenant_id=#{tenant.id}")
    end
  end
end
