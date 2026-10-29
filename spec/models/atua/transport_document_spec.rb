require 'rails_helper'

RSpec.describe Atua::TransportDocument do
  let!(:tenant) { create(:tenant) }
  let!(:other_tenant) { create(:tenant) }

  describe 'associations' do
    context 'with customers, vehicles, manifests and expenses of the same tenant' do
      let!(:sender) { create(:atua_customer, tenant:, code: 7752) }
      let!(:recipient) { create(:atua_customer, tenant:, code: 7761) }
      let!(:consignee) { create(:atua_customer, tenant:, code: 6870) }
      let!(:vehicle) { create(:atua_vehicle, tenant:, code: 812, plate: 'EXU0F72') }
      let!(:trailer) { create(:atua_vehicle, tenant:, code: 813, plate: 'BEV4G50') }
      let!(:manifest) { create(:atua_manifest, tenant:, number: '40798', branch_name: 'JR TRANSPORTES') }
      let!(:transport_document) do
        create(:atua_transport_document, tenant:, code: 80_842, number: '74130', series: 1, branch_name: 'JR TRANSPORTES',
                                         sender_code: 7752, recipient_code: 7761, payer_code: 7752, taker_code: 7752,
                                         consignee_code: 6870, vehicle_code: 812, plate: 'EXU0F72', trailer_plate: 'BEV4G50')
      end
      let!(:link) do
        create(:atua_transport_document_manifest, tenant:, transport_document_code: 80_842, manifest_number: '40798',
                                                  branch_name: 'JR TRANSPORTES')
      end
      let!(:manifest_document) do
        create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: '74130',
                                        transport_document_series: 1, branch_name: 'JR TRANSPORTES')
      end
      let!(:expense) { create(:atua_expense, tenant:, transport_document_code: 80_842, cost_object: transport_document) }

      before do
        create(:atua_customer, tenant: other_tenant, code: 7752)
        create(:atua_vehicle, tenant: other_tenant, code: 812, plate: 'EXU0F72')
        create(:atua_manifest, tenant: other_tenant, number: '40798', branch_name: 'JR TRANSPORTES')
        create(:atua_expense, tenant: other_tenant, transport_document_code: 80_842)
      end

      it 'links every customer role by its code inside the tenant' do
        expect(transport_document.sender).to eq(sender)
        expect(transport_document.recipient).to eq(recipient)
        expect(transport_document.payer).to eq(sender)
        expect(transport_document.taker).to eq(sender)
        expect(transport_document.consignee).to eq(consignee)
        expect(Atua::Customer.count).to eq(4)
      end

      it 'links the vehicle by code and the trailer by plate inside the tenant' do
        expect(transport_document.vehicle).to eq(vehicle)
        expect(transport_document.trailer).to eq(trailer)
      end

      it 'reaches the manifests through the manifest links' do
        expect(transport_document.transport_document_manifests).to eq([link])
        expect(transport_document.manifests).to eq([manifest])
        expect(Atua::Manifest.count).to eq(2)
      end

      it 'reaches the manifest documents by number, series and branch' do
        expect(transport_document.manifest_documents).to eq([manifest_document])
      end

      it 'reaches the expenses linked to it as their cost object' do
        expect(transport_document.expenses).to eq([expense])
        expect(Atua::Expense.count).to eq(2)
      end

      it 'preloads the associations' do
        loaded = described_class.where(tenant:).preload(:sender, :vehicle, :trailer, :manifests, :expenses).first

        expect(loaded.association(:sender)).to be_loaded
        expect(loaded.sender).to eq(sender)
        expect(loaded.manifests).to eq([manifest])
        expect(loaded.expenses).to eq([expense])
      end
    end

    context 'without the related records' do
      let!(:transport_document) { create(:atua_transport_document, tenant:, sender_code: 1, vehicle_code: 2) }

      it 'keeps the document valid with empty associations' do
        expect(transport_document).to be_valid
        expect(transport_document.sender).to be_nil
        expect(transport_document.vehicle).to be_nil
        expect(transport_document.manifests).to be_empty
      end
    end
  end

  describe 'validations' do
    context 'with a document already imported' do
      let!(:transport_document) { create(:atua_transport_document, tenant:, code: 80_842) }

      it 'rejects the same code in the same tenant' do
        duplicated = build(:atua_transport_document, tenant:, code: 80_842)

        expect(duplicated).not_to be_valid
        expect(duplicated.errors[:code]).to eq(['já está em uso'])
      end

      it 'accepts the same code in another tenant' do
        expect(build(:atua_transport_document, tenant: other_tenant, code: transport_document.code)).to be_valid
      end
    end
  end

  describe 'money' do
    it 'exposes the cents columns as reais' do
      transport_document = build(:atua_transport_document, freight_cents: 55_504, icms_cents: nil)

      expect(transport_document.freight).to eq(Money.from_cents(55_504, 'BRL'))
      expect(transport_document.icms).to be_nil
    end
  end

  describe 'scopes' do
    context 'with takers in different customer groups' do
      let!(:group) { create(:customer_group, tenant:, name: 'USIMINAS') }
      let!(:grouped_taker) { create(:atua_customer, tenant:, code: 7100, customer_group: group) }
      let!(:other_taker) { create(:atua_customer, tenant:, code: 7200) }
      let!(:grouped) { create(:atua_transport_document, tenant:, taker_code: grouped_taker.code) }
      let!(:other) { create(:atua_transport_document, tenant:, taker_code: other_taker.code) }

      it 'filters by the customer group of the taker' do
        expect(described_class.by_customer_group(group.id)).to eq([grouped])
        expect(described_class.count).to eq(2)
      end
    end

    context 'with documents of different issuers' do
      let!(:maycon) { create(:atua_transport_document, tenant:, document_kind: 'ce', issuer_code: 6190) }
      let!(:jefferson) { create(:atua_transport_document, tenant:, document_kind: 'ce', issuer_code: 1951) }
      let!(:robot) { create(:atua_transport_document, tenant:, issuer_code: 6001) }
      let!(:unknown) { create(:atua_transport_document, tenant:, issuer_code: nil) }

      it 'leaves out the documents of the given issuers keeping the ones without issuer' do
        expect(described_class.without_issuers([6190, 1951])).to contain_exactly(robot, unknown)
        expect(described_class.without_issuers([])).to contain_exactly(maycon, jefferson, robot, unknown)
        expect(described_class.count).to eq(4)
      end

      it 'takes the codes from a subquery' do
        create(:excluded_issuer, tenant:, code: 6190)

        expect(described_class.without_issuers(ExcludedIssuer.select(:code))).to contain_exactly(jefferson, robot, unknown)
      end
    end

    context 'with documents of different periods, plates, customers and situations' do
      let!(:first) do
        create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 10, 1, 0, 5), posted_on: Date.new(2026, 10, 1),
                                         plate: 'EXU0F72', trailer_plate: 'BEV4G50', sender_code: 7752, payer_code: 7752)
      end
      let!(:last) do
        create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 10, 13, 23, 55), posted_on: Date.new(2026, 10, 14),
                                         plate: 'RHJ4E07', recipient_code: 7752, payer_code: 9000)
      end
      let!(:outside) do
        create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 10, 14, 0, 1), posted_on: Date.new(2026, 10, 14),
                                         plate: 'BEV4G50', consignee_code: 7752, payer_code: 9000)
      end
      let!(:canceled) do
        create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 9, 30, 23, 59), posted_on: Date.new(2026, 9, 30),
                                         canceled_at: Time.zone.local(2026, 10, 2, 10), payer_code: 9000)
      end
      let!(:removed) do
        create(:atua_transport_document, tenant:, issued_at: Time.zone.local(2026, 10, 2), posted_on: Date.new(2026, 10, 2),
                                         removed_from_atua_at: Time.current, payer_code: 9000)
      end

      it 'filters by the whole days of the emission period' do
        expect(described_class.by_period('2026-10-01', '2026-10-13')).to contain_exactly(first, last, removed)
        expect(described_class.by_period(Date.new(2026, 10, 14), nil)).to eq([outside])
        expect(described_class.count).to eq(5)
      end

      it 'filters by the truck or the trailer plate' do
        expect(described_class.by_plate('bev-4g50')).to contain_exactly(first, outside)
      end

      it 'filters by the customer in any role' do
        expect(described_class.by_customer(7752)).to contain_exactly(first, last, outside)
        expect(described_class.by_payer(7752)).to eq([first])
      end

      it 'keeps out canceled documents' do
        expect(described_class.not_canceled).to contain_exactly(first, last, outside, removed)
        expect(described_class.canceled).to eq([canceled])
        expect(canceled).to be_canceled
      end

      it 'filters by the whole days of the launch period' do
        expect(described_class.by_posted_period('2026-10-01', '2026-10-13')).to contain_exactly(first, removed)
        expect(described_class.by_posted_period(Date.new(2026, 10, 14), nil)).to contain_exactly(last, outside)
      end

      it 'filters by the start or the end of the launch period' do
        expect(described_class.by_period_start('2026-10-14')).to contain_exactly(last, outside)
        expect(described_class.by_period_end('2026-10-13')).to contain_exactly(first, canceled, removed)
      end

      it 'filters by the number' do
        expect(described_class.by_number(" #{last.number} ")).to eq([last])
      end

      it 'filters by the situation' do
        expect(described_class.by_situation('canceled')).to eq([canceled])
        expect(described_class.by_situation('valid')).to contain_exactly(first, last, outside, removed)
      end

      it 'keeps out documents removed from Atua' do
        expect(described_class.active).to contain_exactly(first, last, outside, canceled)
        expect(described_class.removed_from_atua).to eq([removed])
        expect(removed).not_to be_active
      end
    end
  end

  describe '.commissionable' do
    context 'with normal, complement, CE, canceled and removed documents' do
      let!(:normal) { create(:atua_transport_document, tenant:) }
      let!(:complement) { create(:atua_transport_document, tenant:, issue_kind: 'Complemento de Valores') }
      let!(:without_issue_kind) { create(:atua_transport_document, tenant:, issue_kind: nil) }
      let!(:ce) { create(:atua_transport_document, tenant:, document_kind: 'ce') }
      let!(:canceled) { create(:atua_transport_document, tenant:, canceled_at: Time.current) }
      let!(:removed) { create(:atua_transport_document, tenant:, removed_from_atua_at: Time.current) }

      it 'keeps only the active and valid CT-es that are not a value complement' do
        expect(described_class.count).to eq(6)
        expect(described_class.commissionable).to contain_exactly(normal, without_issue_kind)
      end
    end
  end

  describe '.by_axles and .without_axles' do
    context 'with transport documents of sets with different axle counts' do
      let!(:rodotrem) { create(:atua_transport_document, tenant:, plate: 'RDT9A99', axles: 9) }
      let!(:ls_on_rodotrem) { create(:atua_transport_document, tenant:, plate: 'RDT9A99', axles: 6) }
      let!(:quarto_eixo) { create(:atua_transport_document, tenant:, plate: 'QTE7B77', axles: 7) }
      let!(:truck) { create(:atua_transport_document, tenant:, plate: 'TRK3E33', axles: 3) }
      let!(:without_axles) { create(:atua_transport_document, tenant:, plate: 'TRK3E33', axles: nil) }

      it 'keeps the transport documents whose own axle count is in the axle counts' do
        expect(described_class.count).to eq(5)
        expect(described_class.by_axles([9])).to eq([rodotrem])
        expect(described_class.by_axles([6, 7])).to contain_exactly(ls_on_rodotrem, quarto_eixo)
        expect(described_class.by_axles([])).to be_empty
      end

      it 'keeps the transport documents whose own axle count is out of the axle counts or missing' do
        expect(described_class.without_axles([9, 7, 6])).to contain_exactly(truck, without_axles)
        expect(described_class.without_axles([]).count).to eq(5)
      end
    end
  end

  describe '.toll_in_freight' do
    context 'with tolls inside and outside the gross freight' do
      let!(:included) do
        create(:atua_transport_document, tenant:, freight_cents: 1_992_609, weight_freight_cents: 1_761_810, toll_cents: 98_190,
                                         icms_cents: 132_609)
      end
      let!(:rounded) do
        create(:atua_transport_document, tenant:, freight_cents: 590_001, weight_freight_cents: 569_140, toll_cents: 20_860, icms_cents: nil)
      end
      let!(:voucher) do
        create(:atua_transport_document, tenant:, freight_cents: 929_241, weight_freight_cents: 929_241, toll_cents: 103_867, icms_cents: 0)
      end
      let!(:without_toll) do
        create(:atua_transport_document, tenant:, freight_cents: 892_267, weight_freight_cents: 785_195, toll_cents: 0, icms_cents: 107_072)
      end

      it 'keeps only the documents whose gross freight already carries the toll' do
        expect(described_class.count).to eq(4)
        expect(described_class.toll_in_freight).to contain_exactly(included, rounded)
        expect(described_class.toll_in_freight.sum(:toll_cents)).to eq(119_050)
      end

      it 'keeps apart the documents whose toll is outside the gross freight' do
        expect(described_class.toll_outside_freight).to eq([voucher])
      end

      it 'tells where the toll of each document is' do
        expect([included, rounded, voucher, without_toll].map(&:toll_placement)).to eq(%i[in_freight in_freight outside_freight none])
      end
    end
  end

  describe 'toll from Atua' do
    context 'with the toll kind and the voucher issuer imported from Atua' do
      let(:transport_document) do
        build(:atua_transport_document, raw_data: { 'id_pedagio_ctrc' => 'Cobrar + Pedágio', 'nm_emissao_vale_pedagio' => 'EFRETE TAG - SEM PARAR' })
      end

      it 'reads them from the imported row' do
        expect(transport_document.atua_toll_kind).to eq('Cobrar + Pedágio')
        expect(transport_document.toll_voucher_issuer).to eq('EFRETE TAG - SEM PARAR')
      end
    end

    context 'without the toll columns in the imported row' do
      let(:transport_document) { build(:atua_transport_document, raw_data: { 'id_pedagio_ctrc' => '' }) }

      it 'returns nothing' do
        expect(transport_document.atua_toll_kind).to be_nil
        expect(transport_document.toll_voucher_issuer).to be_nil
      end
    end
  end

  describe '.taker_names_by_code' do
    context 'with documents of takers named in different ways' do
      let!(:first) { create(:atua_transport_document, tenant:, taker_code: 501, taker_name: 'USIMINAS CUBATAO') }
      let!(:second) { create(:atua_transport_document, tenant:, taker_code: 501, taker_name: 'USIMINAS IPATINGA') }
      let!(:repeated) { create(:atua_transport_document, tenant:, taker_code: 501, taker_name: 'USIMINAS CUBATAO') }
      let!(:other) { create(:atua_transport_document, tenant:, taker_code: 777, taker_name: 'FIAT') }
      let!(:blank) { create(:atua_transport_document, tenant:, taker_code: 888, taker_name: '') }

      it 'groups the distinct taker names by the taker code' do
        result = described_class.taker_names_by_code

        expect(described_class.count).to eq(5)
        expect(result.keys).to contain_exactly(501, 777)
        expect(result[501]).to contain_exactly('USIMINAS CUBATAO', 'USIMINAS IPATINGA')
        expect(result[777]).to eq(['FIAT'])
      end
    end
  end

  describe '.statuses' do
    it 'maps the translated situations to the filter keys' do
      expect(described_class.statuses).to eq('Válido' => :valid, 'Cancelado' => :canceled)
    end
  end
end
