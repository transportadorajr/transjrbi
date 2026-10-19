require 'rails_helper'

RSpec.describe Atua::FailImportCommand do
  let!(:tenant) { create(:tenant, trade_name: 'TransJR') }
  let(:error) { Atua::AuthenticationError.new('A Atua recusou o login.') }

  def failed_import(finished_at, report_type: 'manifests', target: tenant)
    create(:atua_import, tenant: target, report_type:, status_type: 'failed', error_type: 'download', finished_at:)
  end

  def running_import
    create(:atua_import, tenant:, report_type: 'manifests', status_type: 'running', started_at: Time.current)
  end

  describe '.call' do
    it 'records the message and the type of an Atua error' do
      import = described_class.call(running_import, error)

      expect(import.reload).to have_attributes(status_type: 'failed', error_type: 'authentication', error_message: 'A Atua recusou o login.')
      expect(import.finished_at).to be_present
    end

    it 'maps each Atua error class to its type' do
      {
        Atua::ConfigurationError => 'configuration', Atua::DeviceVerificationError => 'device_verification', Atua::SessionError => 'session', Atua::DownloadError => 'download',
        Atua::SpreadsheetError => 'spreadsheet', Atua::LayoutError => 'layout', Atua::ConversionError => 'conversion',
        Atua::UnavailableError => 'unexpected', Atua::Error => 'unexpected', ActiveRecord::StatementInvalid => 'unexpected'
      }.each do |error_class, error_type|
        expect(described_class.call(running_import, error_class.new('falhou')).error_type).to eq(error_type)
      end
    end

    context 'with an admin user to notify', :inline_jobs do
      let!(:admin_user) { create(:admin_user, email: 'marina@transjrbi.com.br') }

      context 'when the report failed twice in a row' do
        before do
          create(:atua_import, tenant:, report_type: 'manifests', status_type: 'succeeded', finished_at: 3.hours.ago)
          failed_import(2.hours.ago)
          failed_import(1.hour.ago)
          failed_import(10.minutes.ago, report_type: 'expenses')
          failed_import(5.minutes.ago, target: create(:tenant))
        end

        it 'sends one e-mail on the third failure of the same report and tenant' do
          expect { described_class.call(running_import, error) }.to change(ActionMailer::Base.deliveries, :count).by(1)

          mail = ActionMailer::Base.deliveries.last
          expect(mail.to).to eq(['marina@transjrbi.com.br'])
          expect(mail.subject).to eq('Atua: importação de Manifestos da TransJR falhou seguidamente')
        end
      end

      context 'when the report already failed three times in a row' do
        before { 3.times { |index| failed_import((index + 1).hours.ago) } }

        it 'does not send the e-mail again' do
          expect { described_class.call(running_import, error) }.not_to change(ActionMailer::Base.deliveries, :count)
        end
      end

      context 'when the report failed only once before' do
        before { failed_import(1.hour.ago) }

        it 'does not send any e-mail' do
          expect { described_class.call(running_import, error) }.not_to change(ActionMailer::Base.deliveries, :count)
        end
      end
    end

    context 'without admin users' do
      before { 2.times { |index| failed_import((index + 1).hours.ago) } }

      it 'only logs the failure streak', :inline_jobs do
        allow(Rails.logger).to receive(:error)

        expect { described_class.call(running_import, error) }.not_to change(ActionMailer::Base.deliveries, :count)
        expect(Rails.logger).to have_received(:error).with(/3 consecutive failures of manifests for tenant #{tenant.id}/)
      end
    end
  end
end
