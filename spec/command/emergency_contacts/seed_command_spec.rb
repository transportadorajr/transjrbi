require 'rails_helper'

RSpec.describe EmergencyContacts::SeedCommand do
  let(:file) { file_fixture('emergency_contacts.json') }
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant, name: 'Outra Transportadora Ltda', trade_name: 'Outra') }
  let!(:jose) { create(:employee, tenant:, name: 'JOSE DA SILVA', company_type: 'mme', registration: '00901', legal_id: nil) }
  let!(:pablo) { create(:employee, tenant:, name: 'PABLO GOMEZ', company_type: 'mme', registration: '00902', legal_id: nil) }
  let!(:carlos) { create(:employee, tenant:, name: 'CARLOS SOUZA', company_type: 'mm_espinola', registration: '00903', legal_id: nil) }

  def contacts_of(employee)
    employee.emergency_contacts.reload
      .map { |contact| contact.slice(:name, :relationship_type, :phone, :secondary_phone, :position, :notes).symbolize_keys }
  end

  describe '.call' do
    before { create(:employee, tenant: other_tenant, name: 'JOSE DA SILVA', company_type: 'mme', registration: '00901', legal_id: nil) }

    it 'registers the emergency contacts of the spreadsheet by the registration of the employee' do
      expect { described_class.call(tenant, file:) }.to change(EmergencyContact, :count).by(4)

      expect(contacts_of(jose)).to eq(
        [
          { name: 'Maria da Silva', relationship_type: 'spouse', phone: '45999990001', secondary_phone: nil, position: 1, notes: nil },
          { name: 'Ana da Silva', relationship_type: 'mother', phone: '45999990002', secondary_phone: nil, position: 2, notes: nil },
        ],
      )
      expect(contacts_of(pablo)).to eq(
        [{ name: 'Lucía Gomez', relationship_type: 'spouse', phone: '+5493750000000', secondary_phone: '45999990003', position: 1, notes: nil }],
      )
      expect(contacts_of(carlos)).to eq(
        [
          { name: 'Paula Souza', relationship_type: 'spouse', phone: nil, secondary_phone: nil, position: 1,
            notes: 'Conferir o telefone da planilha: (45)9.99999-0004' },
        ],
      )
      expect(other_tenant.emergency_contacts.count).to eq(0)
    end

    it 'can run again without duplicating the emergency contacts' do
      described_class.call(tenant, file:)

      expect { described_class.call(tenant, file:) }.not_to change(EmergencyContact, :count)
    end

    it 'keeps the emergency contacts already registered by the HR' do
      registered = create(:emergency_contact, employee: jose, name: 'Contato do RH')

      described_class.call(tenant, file:)

      expect(jose.emergency_contacts.reload).to eq([registered])
    end

    context 'when an employee registered on the screen has no registration' do
      let!(:marcos) { create(:employee, tenant:, name: 'Marcos Peréira', company_type: 'mme', legal_id: nil) }
      let!(:pedro) { create(:employee, tenant:, name: 'PEDRO LIMA', company_type: 'mm_espinola', legal_id: nil) }

      before { create(:employee, tenant:, name: 'PEDRO LIMA', company_type: 'transjr', legal_id: nil) }

      it 'finds the employee by the name and skips a name shared by two employees' do
        described_class.call(tenant, file:)

        expect(contacts_of(marcos).map { |contact| contact.slice(:name, :phone) }).to eq([{ name: 'Julia Pereira', phone: '45999990005' }])
        expect(pedro.emergency_contacts).to be_empty
      end
    end

    context 'when the name of the employee was cut at 30 characters' do
      let!(:roberto) { create(:employee, tenant:, name: 'ROBERTO ALMEIDA DOS SANTOS FER', company_type: 'mme', legal_id: nil) }

      it 'finds the employee by the beginning of the name' do
        described_class.call(tenant, file:)

        expect(roberto.emergency_contacts.map(&:name)).to eq(['Clara Ferreira'])
      end
    end

    context 'when the encrypted file cannot be read without the master key' do
      let(:file) { ActiveSupport::EncryptedFile.new(content_path: 'config/emergency_contacts.json.enc', key_path: 'tmp/missing.key', env_key: 'MISSING_KEY', raise_if_missing_key: false) }

      it 'skips the seed' do
        expect { described_class.call(tenant, file:) }.not_to change(EmergencyContact, :count)
      end
    end
  end
end
