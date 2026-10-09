require 'rails_helper'

RSpec.describe UserMailer do
  describe '#confirmation_instructions' do
    context 'with a new account' do
      let(:user) { create(:user, name: 'Ana Paula', email: 'ana@transjrbi.com.br', confirmed_at: nil) }

      it 'asks the user to confirm the account and define the password' do
        mail = described_class.confirmation_instructions(user, 'token123')

        expect(mail.to).to eq(['ana@transjrbi.com.br'])
        expect(mail.subject).to eq('Confirme sua conta no TransJRBI')
        expect(mail.body.encoded).to include('Olá, Ana Paula!')
        expect(mail.body.encoded).to include('Confirmar conta e definir senha')
        expect(mail.body.encoded).to include('/users/confirmation?confirmation_token=token123')
        expect(mail.body.encoded).to include('Este link é válido por 3 dias.')
      end
    end

    context 'with an e-mail change' do
      let(:user) { create(:user, email: 'ana@transjrbi.com.br') }

      before { user.update!(email: 'ana.paula@transjrbi.com.br') }

      it 'keeps the default e-mail confirmation instructions' do
        mail = described_class.confirmation_instructions(user, 'token123', to: user.unconfirmed_email)

        expect(mail.to).to eq(['ana.paula@transjrbi.com.br'])
        expect(mail.subject).to eq('Instruções de confirmação')
        expect(mail.body.encoded).to include('Confirmar minha conta')
      end
    end
  end
end
