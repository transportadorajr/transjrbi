require 'rails_helper'

RSpec.describe MaintenanceOrderSignature do
  let(:tenant) { create(:tenant) }
  let(:maintenance_order) { create(:maintenance_order, tenant:) }
  let(:mechanic) { create(:workshop_employee, tenant:, name: 'CARLOS SOUZA') }

  describe 'validations' do
    it 'requires the signer, the moment, the digest and a drawn signature' do
      signature = build(:maintenance_order_signature, maintenance_order:, workshop_employee: mechanic, signer_name: '', signed_at: nil,
                                                      content_digest: '', strokes: [[[0.1, 0.1]]])

      expect(signature).not_to be_valid
      expect(signature.errors.full_messages).to contain_exactly('Nome não pode ficar em branco', 'Assinada em não pode ficar em branco',
                                                                'Código de verificação não pode ficar em branco',
                                                                'Assinatura não pode ficar em branco')
    end

    it 'rejects an unknown role' do
      signature = build(:maintenance_order_signature, maintenance_order:, signer_role_type: 'driver')

      expect(signature).not_to be_valid
      expect(signature.errors.full_messages).to eq(['Função não está incluído na lista'])
    end

    it 'accepts one signature per employee and role in the order' do
      create(:maintenance_order_signature, maintenance_order:, workshop_employee: mechanic, signer_role_type: 'mechanic')

      expect(build(:maintenance_order_signature, maintenance_order:, workshop_employee: mechanic, signer_role_type: 'mechanic'))
        .not_to be_valid
      expect(build(:maintenance_order_signature, maintenance_order:, workshop_employee: mechanic, signer_role_type: 'supervisor'))
        .to be_valid
    end
  end

  describe 'enums' do
    it 'translates the role of the signer' do
      expect(build(:maintenance_order_signature, signer_role_type: 'supervisor').signer_role_type_name).to eq('Encarregado')
      expect(build(:maintenance_order_signature, signer_role_type: 'mechanic').signer_role_type_name).to eq('Mecânico')
    end
  end

  describe '.parse_strokes' do
    it 'keeps the points rounded to three decimals' do
      expect(described_class.parse_strokes('[[[0.12345, 0.5], [1, 0]], [[0.3, 0.98765]]]'))
        .to eq([[[0.123, 0.5], [1.0, 0.0]], [[0.3, 0.988]]])
    end

    it 'drops the strokes with points out of the pad or that are not numbers' do
      json = [[[0.1, 0.2]], [[1.5, 0.2]], [['0.1', 0.2]], [[0.1]], [], 'x', [[0.1, 0.2, 0.3]]].to_json

      expect(described_class.parse_strokes(json)).to eq([[[0.1, 0.2]]])
    end

    it 'ignores anything that is not a list of strokes' do
      expect(described_class.parse_strokes(nil)).to eq([])
      expect(described_class.parse_strokes('<svg onload="alert(1)">')).to eq([])
      expect(described_class.parse_strokes('{"strokes": []}')).to eq([])
      expect(described_class.parse_strokes(Array.new(101) { [[0.1, 0.1]] }.to_json)).to eq([])
    end
  end

  describe '.drawn?' do
    it 'needs enough points to be more than a tap and not too many' do
      expect(described_class.drawn?([Array.new(9) { [0.1, 0.1] }])).to be(false)
      expect(described_class.drawn?([Array.new(5) { [0.1, 0.1] }, Array.new(5) { [0.2, 0.2] }])).to be(true)
      expect(described_class.drawn?([Array.new(5_001) { [0.1, 0.1] }])).to be(false)
    end
  end

  describe '#to_svg' do
    it 'draws each stroke as a path scaled to the pad' do
      signature = build(:maintenance_order_signature, strokes: [[[0.1, 0.5], [0.2, 0.25]], [[0.5, 0.5]]])

      expect(signature.to_svg).to eq(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 100">' \
        '<g fill="none" stroke="#111111" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' \
        '<path d="M 30.0 50.0 L 60.0 25.0"/><path d="M 150.0 50.0 L 150.0 50.0"/></g></svg>',
      )
    end
  end

  describe '.enabled?' do
    it 'follows the flag of the tenant' do
      expect(described_class.enabled?(tenant)).to be(false)

      Flipper.enable_actor(:maintenance_order_signatures, tenant)

      expect(described_class.enabled?(tenant)).to be(true)
    end
  end
end
