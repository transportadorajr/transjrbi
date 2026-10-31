require 'rails_helper'

RSpec.describe Atua::ImportAllCommand do
  let(:tenant) { create(:tenant) }
  let(:base_url) { 'http://localhost:4567/adm' }
  let(:configuration) { Atua::Configuration.new(base_url:, username: 'transjr', password: 'secret-password') }
  let(:client) { Atua::Client.new(configuration) }
  let(:endpoints) do
    {
      customers: 'rel_cliente_detalhado.php',
      vehicles: 'rel_veiculo_terceiro_detalhado.php',
      manifests: 'rel_manifesto_detalhado.php',
      transport_documents: 'rel_ctrc_detalhado.php',
      expenses: 'rel_caixa_detalhado.php',
      toll_vouchers: 'rel_ctrc_vale_pedagio.php',
    }
  end
  let(:login_form) do
    <<~HTML
      <html><body><form action="login.php" method="post">
        <input type="hidden" name="f_form_login_submitted" value="1">
        <input type="text" name="f_ds_apelido" value="">
        <input type="password" name="f_ds_senha" value="">
        <input type="submit" name="submete051031" value="Acessar">
      </form></body></html>
    HTML
  end

  before do
    allow(Atua::Configuration).to receive(:for).with(tenant).and_return(configuration)
    allow(Atua::Client).to receive(:new).with(configuration).and_return(client)
    allow(client).to receive(:pause)
    stub_request(:get, "#{base_url}/login.php?f_popup=true").to_return(status: 200, body: login_form)
  end

  context 'when Atua accepts the login' do
    before do
      stub_request(:post, "#{base_url}/login.php").to_return(status: 200, body: '<div class="login-status-ok">Acesso Aceito!</div>')
      endpoints.each do |report_type, endpoint|
        stub_request(:get, "#{base_url}/#{endpoint}").to_return(status: 200, body: '<form></form>')
        stub_request(:post, "#{base_url}/#{endpoint}")
          .to_return(status: 200, body: atua_fixture_path(report_type).binread, headers: { 'Content-Type' => 'application/vnd.ms-excel' })
      end
    end

    it 'imports every report in order reusing the same session' do
      imports = described_class.call(tenant, start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 13))

      expect(imports.map(&:report_type)).to eq(%w[customers vehicles manifests transport_documents expenses toll_vouchers])
      expect(imports.map(&:status_type)).to all(eq('succeeded'))
      expect(imports.map { |import| [import.start_date, import.end_date] }).to eq(
        [[nil, nil], [nil, nil]] + ([[Date.new(2026, 10, 1), Date.new(2026, 10, 13)]] * 4),
      )
      expect(imports.map(&:inserted_count)).to eq([4833, 1391, 217, 420, 1217, 3])
      expect(a_request(:post, "#{base_url}/login.php")).to have_been_made.once
      expect(tenant.atua_transport_documents.find_by!(code: 80_842).sender).to be_present
    end
  end

  context 'when Atua refuses the login' do
    before do
      stub_request(:post, "#{base_url}/login.php").to_return(status: 200, body: login_form)
    end

    it 'records the failure and stops without trying to log in again' do
      imports = described_class.call(tenant, start_date: Date.new(2026, 10, 1), end_date: Date.new(2026, 10, 13))

      expect(imports.map(&:report_type)).to eq(%w[customers])
      expect(imports.sole).to have_attributes(
        status_type: 'failed', error_message: 'A Atua recusou o login, a resposta ainda contém o formulário de login.',
      )
      expect(a_request(:post, "#{base_url}/login.php")).to have_been_made.once
      expect(Atua::Import.count).to eq(1)
    end
  end
end
