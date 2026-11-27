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

    it 'accepts the known cargo destinations or none' do
      expect(build(:atua_transport_document, tenant:, cargo_destination_type: :export)).to be_cargo_export
      expect(build(:atua_transport_document, tenant:, cargo_destination_type: nil)).to be_valid
      expect(build(:atua_transport_document, tenant:, cargo_destination_type: 'transit')).not_to be_valid
    end

    it 'translates the cargo destinations' do
      expect(described_class.human_enum_name(:cargo_destination_type, :export)).to eq('Exportação')
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

      it 'filters by the taker' do
        expect(described_class.by_taker(other_taker.code)).to eq([other])
      end

      it 'filters by the customer group of the taker' do
        expect(described_class.by_customer_group(group.id)).to eq([grouped])
        expect(described_class.count).to eq(2)
      end
    end

    context 'with documents of different drivers' do
      let!(:first) { create(:atua_transport_document, tenant:, driver_code: 10, driver_name: 'MARIA SOUZA') }
      let!(:second) { create(:atua_transport_document, tenant:, driver_code: 10, driver_name: 'MARIA SOUZA') }
      let!(:third) { create(:atua_transport_document, tenant:, driver_code: 20, driver_name: 'ANA LIMA') }

      before do
        create(:atua_transport_document, tenant:, driver_code: nil)
        create(:atua_transport_document, tenant:, driver_code: 30, driver_name: 'JOAO REMOVIDO', removed_from_atua_at: Time.current)
      end

      it 'filters by the driver' do
        expect(described_class.count).to eq(5)
        expect(described_class.by_driver(10)).to contain_exactly(first, second)
      end

      it 'lists each driver of the active documents once, ordered by name' do
        expect(described_class.drivers.map { |driver| [driver.driver_code, driver.driver_name] }).to eq([[20, 'ANA LIMA'], [10, 'MARIA SOUZA']])
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

    context 'with a vehicle sale and a freight' do
      let!(:vehicle_sale) { create(:atua_transport_document, tenant:, document_kind: 'ce', vehicle_sale: true) }
      let!(:freight) { create(:atua_transport_document, tenant:) }

      it 'separates the vehicle sales from the freights' do
        expect(described_class.vehicle_sales).to contain_exactly(vehicle_sale)
        expect(described_class.freights).to contain_exactly(freight)
        expect(described_class.count).to eq(2)
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

      it 'keeps out documents removed from Atua' do
        expect(described_class.active).to contain_exactly(first, last, outside, canceled)
        expect(described_class.removed_from_atua).to eq([removed])
        expect(removed).not_to be_active
      end
    end
  end

  describe '.recently_issued' do
    let!(:recent) { create(:atua_transport_document, tenant:, issued_at: 11.months.ago) }

    before { create(:atua_transport_document, tenant:, issued_at: 13.months.ago) }

    it 'returns only the documents issued in the last twelve months' do
      expect(described_class.recently_issued).to contain_exactly(recent)
    end
  end

  describe '.by_document_kind' do
    let!(:cte) { create(:atua_transport_document, tenant:, document_kind: 'cte') }
    let!(:ce) { create(:atua_transport_document, tenant:, document_kind: 'ce') }

    it 'returns only the documents of the given kind' do
      expect(described_class.by_document_kind('ce')).to contain_exactly(ce)
      expect(described_class.by_document_kind('cte')).to contain_exactly(cte)
    end
  end

  describe '.document_kinds' do
    it 'maps the translated kinds to the stored values' do
      expect(described_class.document_kinds).to eq('CT-e' => 'cte', 'CE' => 'ce')
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

  describe '.by_product_group' do
    let(:tenant) { create(:tenant) }
    let!(:steel) { create(:product_group, tenant:) }
    let!(:coil) { create(:product_subgroup, tenant:, parent: steel) }
    let!(:rebar) { create(:product_subgroup, tenant:, parent: steel) }
    let!(:coil_document) { create(:atua_transport_document, tenant:, product_group: coil) }
    let!(:rebar_document) { create(:atua_transport_document, tenant:, product_group: rebar) }
    let!(:loose_document) { create(:atua_transport_document, tenant:) }

    it 'keeps the documents of every subgroup of the group' do
      expect(described_class.by_product_group(steel.id)).to contain_exactly(coil_document, rebar_document)
    end

    it 'keeps no document for a subgroup' do
      expect(described_class.by_product_group(coil.id)).to be_empty
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

  describe '.by_truck_group and .without_truck_group' do
    let!(:rodotrem_group) { create(:truck_group, tenant:, name: 'Rodotrem', axles: [9]) }
    let!(:utinga_group) { create(:truck_group, :utinga, tenant:) }
    let!(:rodotrem) { create(:atua_transport_document, tenant:, plate: 'RDT9A99', axles: 9) }
    let!(:utinga_rodotrem) { create(:atua_transport_document, tenant:, plate: 'BAV5A04', axles: 9) }
    let!(:utinga_ls) { create(:atua_transport_document, tenant:, plate: 'EVO8C24', axles: 6) }
    let!(:ls) { create(:atua_transport_document, tenant:, plate: 'LSS6C66', axles: 6) }
    let!(:without_axles) { create(:atua_transport_document, tenant:, plate: nil, axles: nil) }
    let(:grouped_plates) { utinga_group.plates }

    it 'keeps the transport documents of the plates of the group or of its axle count outside the grouped plates' do
      expect(described_class.count).to eq(5)
      expect(described_class.by_truck_group(utinga_group, grouped_plates)).to contain_exactly(utinga_rodotrem, utinga_ls)
      expect(described_class.by_truck_group(rodotrem_group, grouped_plates)).to eq([rodotrem])
    end

    it 'keeps every other transport document, even without plate or axle count' do
      expect(described_class.without_truck_group(utinga_group, grouped_plates)).to contain_exactly(rodotrem, ls, without_axles)
      expect(described_class.without_truck_group(rodotrem_group, grouped_plates)).to contain_exactly(utinga_rodotrem, utinga_ls, ls, without_axles)
    end
  end

  describe '#linked_manifests' do
    context 'with manifests linked by the CT-e report and by the MDF-e report' do
      let!(:transport_document) do
        create(:atua_transport_document, tenant:, code: 80_842, number: '74130', series: 1, branch_name: 'JR TRANSPORTES')
      end
      let!(:linked_by_transport_document) { create(:atua_manifest, tenant:, code: 41_317, number: '41317') }
      let!(:linked_by_both) { create(:atua_manifest, tenant:, code: 41_340, number: '41340') }
      let!(:issued_later) { create(:atua_manifest, tenant:, code: 41_365, number: '41365', issued_on: Date.new(2026, 11, 1)) }
      let!(:removed_document) { create(:atua_manifest, tenant:, code: 41_370, number: '41370') }

      before do
        create(:atua_manifest, tenant:, code: 41_380, number: '41380')
        create(:atua_manifest, tenant: other_tenant, code: 41_365, number: '41365')
        [linked_by_transport_document, linked_by_both].each do |manifest|
          create(:atua_transport_document_manifest, tenant:, transport_document_code: 80_842, manifest_number: manifest.number,
                                                    branch_name: 'JR TRANSPORTES')
        end
        [linked_by_both, issued_later].each do |manifest|
          create(:atua_manifest_document, tenant:, manifest_code: manifest.code, transport_document_number: '74130',
                                          transport_document_series: 1, branch_name: 'JR TRANSPORTES')
        end
        create(:atua_manifest_document, tenant:, manifest_code: removed_document.code, transport_document_number: '74130',
                                        transport_document_series: 1, branch_name: 'JR TRANSPORTES', removed_from_atua_at: Time.current)
        create(:atua_manifest_document, tenant: other_tenant, manifest_code: 41_365, transport_document_number: '74130',
                                        transport_document_series: 1, branch_name: 'JR TRANSPORTES')
      end

      it 'lists the manifests of both reports once, even when the CT-e report does not know the manifest' do
        expect(Atua::Manifest.count).to eq(6)
        expect(transport_document.manifests).to contain_exactly(linked_by_transport_document, linked_by_both)
        expect(transport_document.linked_manifests).to contain_exactly(linked_by_transport_document, linked_by_both, issued_later)
      end
    end
  end

  describe '#driver_display_name' do
    it 'returns the display name of the registered driver' do
      create(:driver, tenant:, code: 20, display_name: 'MARIA')
      transport_document = create(:atua_transport_document, tenant:, driver_code: 20, driver_name: 'MARIA SOUZA')

      expect(transport_document.driver_display_name).to eq('MARIA')
    end

    it 'returns the driver name of the document when the driver is not registered' do
      create(:driver, tenant: other_tenant, code: 20, display_name: 'MARIA')
      transport_document = create(:atua_transport_document, tenant:, driver_code: 20, driver_name: 'MARIA SOUZA')

      expect(transport_document.driver_display_name).to eq('MARIA SOUZA')
    end

    it 'returns no name when the document has no driver' do
      transport_document = create(:atua_transport_document, tenant:, driver_code: nil, driver_name: '')

      expect(transport_document.driver_display_name).to be_nil
    end
  end

  describe '#toll_placement' do
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

      it 'tells where the toll of each document is' do
        expect([included, rounded, voucher, without_toll].map(&:toll_placement)).to eq(%i[in_freight in_freight outside_freight none])
      end
    end
  end

  describe '.discounted_toll' do
    def document(number, toll_cents)
      create(:atua_transport_document, tenant:, number:, branch_code: 2, freight_cents: 400_000 + toll_cents, weight_freight_cents: 400_000,
                                       toll_cents:, icms_cents: 0)
    end

    def voucher(number, company_toll_kind, charged_toll_cents, toll_cents)
      create(:atua_toll_voucher, tenant:, transport_document_number: number, branch_code: 2, charged_toll_cents:, toll_cents:,
                                 raw_data: { 'id_pedagio_empresa' => company_toll_kind })
    end

    let!(:with_toll_in_freight) { document('74754', 47_770) }
    let!(:included_without_toll) { document('74800', 0) }
    let!(:included_without_company_toll) { document('74801', 0) }
    let!(:paid_on_tag) { document('74817', 0) }
    let!(:route_without_toll) { document('74765', 0) }
    let!(:without_voucher) { document('74802', 0) }

    before do
      voucher('74754', 1.0, 47_770, 176_193)
      voucher('74800', 1.0, 50_000, 150_000)
      voucher('74801', 1.0, 0, 90_000)
      voucher('74817', 3.0, 103_544, 103_544)
      voucher('74765', 0.0, 0, 74_640)
    end

    it 'takes the toll of the transport document first, then the company toll of an included voucher, then the driver toll of the voucher' do
      documents = [with_toll_in_freight, included_without_toll, included_without_company_toll, paid_on_tag, route_without_toll, without_voucher]
      tolls = described_class.where(id: documents).order(:number).pluck(:number, described_class.discounted_toll)

      expect(Atua::TollVoucher.count).to eq(5)
      expect(tolls.map { |number, cents| [number, cents.to_i] }).to eq(
        [['74754', 47_770], ['74765', 74_640], ['74800', 50_000], ['74801', 90_000], ['74802', 0], ['74817', 103_544]],
      )
    end

    context 'when the customer group of the taker has its toll reimbursed' do
      let!(:reimbursed_group) { create(:customer_group, tenant:, name: 'INDEMIL', toll_reimbursed: true) }
      let!(:other_tenant_group) { create(:customer_group, tenant: create(:tenant), name: 'INDEMIL', toll_reimbursed: true) }

      before do
        create(:atua_customer, tenant:, code: 341, customer_group: reimbursed_group)
        create(:atua_customer, tenant: other_tenant_group.tenant, code: 342, customer_group: other_tenant_group)
        route_without_toll.update!(taker_code: 341)
        with_toll_in_freight.update!(taker_code: 341)
        paid_on_tag.update!(taker_code: 342)
      end

      it 'moves the toll from the discounted toll to the toll paid by the customer' do
        documents = [with_toll_in_freight, route_without_toll, paid_on_tag]
        tolls = described_class.where(id: documents).order(:number)
          .pluck(:number, described_class.discounted_toll, described_class.undiscounted_toll)

        expect(tolls.map { |number, discounted, undiscounted| [number, discounted.to_i, undiscounted.to_i] }).to eq(
          [['74754', 0, 47_770], ['74765', 0, 74_640], ['74817', 103_544, 0]],
        )
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

  describe 'value complements' do
    let(:tenant) { create(:tenant) }
    let!(:original) { create(:atua_transport_document, tenant:, number: '67991', freight_cents: 1_066_836) }
    let!(:complement) do
      create(:atua_transport_document, tenant:, number: '68005', issue_kind: described_class::VALUE_COMPLEMENT, freight_cents: 73_600,
                                       complemented_transport_document: original)
    end
    let!(:canceled_complement) do
      create(:atua_transport_document, tenant:, number: '68006', issue_kind: described_class::VALUE_COMPLEMENT, freight_cents: 50_000,
                                       complemented_transport_document: original, canceled_at: Time.current)
    end
    let!(:unlinked_complement) do
      create(:atua_transport_document, tenant:, number: '68007', issue_kind: described_class::VALUE_COMPLEMENT, freight_cents: 40_000)
    end

    before { create(:atua_expense, tenant:, history_code: 72, cost_object: original, total_cents: 73_600) }

    it 'credits the valid complements to the expenses of the original without changing its gross freight' do
      totals = described_class.where(tenant:).with_freight_totals.index_by(&:number)

      expect(totals['67991'].freight_cents).to eq(1_066_836)
      expect(totals['67991'].net_cents).to eq(1_066_836)
    end

    it 'transfers the value of a linked complement to the original, leaving the complement without net freight' do
      totals = described_class.where(tenant:).with_freight_totals.index_by(&:number)

      expect(totals['68005'].freight_cents).to eq(73_600)
      expect(totals['68005'].net_cents).to eq(0)
      expect(totals['68007'].net_cents).to eq(40_000)
    end

    it 'lists the valid complements credited to the original' do
      expect(original.complement_credits).to eq([complement])
      expect(complement.complement_credit).to eq(Money.from_cents(-73_600))
    end

    it 'transfers only the value of a valid linked complement' do
      expect(complement.complement_transfer).to eq(Money.from_cents(73_600))
      expect(canceled_complement.complement_transfer).to eq(Money.from_cents(0))
      expect(unlinked_complement.complement_transfer).to eq(Money.from_cents(0))
      expect(original.complement_transfer).to eq(Money.from_cents(0))
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

  describe 'advance ICMS' do
    let!(:gerdau) { create(:customer_group, tenant:, name: 'GERDAU', pays_advance_icms_at: Time.current) }
    let!(:usiminas) { create(:customer_group, tenant:, name: 'USIMINAS') }
    let!(:other_tenant_gerdau) { create(:customer_group, tenant: other_tenant, name: 'GERDAU', pays_advance_icms_at: Time.current) }
    let!(:gerdau_customer) { create(:atua_customer, tenant:, code: 601, customer_group: gerdau) }
    let!(:usiminas_customer) { create(:atua_customer, tenant:, code: 602, customer_group: usiminas) }
    let!(:other_tenant_customer) { create(:atua_customer, tenant: other_tenant, code: 602, customer_group: other_tenant_gerdau) }
    let!(:paid) do
      create(:atua_transport_document, tenant:, number: '75830', cfop: 6932, origin_state: 'SP', taker_code: 601, freight_cents: 170_395,
                                       icms_cents: 20_447)
    end
    let!(:divergent) do
      create(:atua_transport_document, tenant:, number: '75831', cfop: 5932, origin_state: 'SP', taker_code: 601, freight_cents: 41_598,
                                       icms_cents: 4_992)
    end
    let!(:pending) do
      create(:atua_transport_document, tenant:, number: '75845', cfop: 6932, origin_state: 'SP', taker_code: 601, freight_cents: 72_343,
                                       icms_cents: 8_681)
    end
    let!(:not_expected) do
      create(:atua_transport_document, tenant:, number: '75846', cfop: 6932, origin_state: 'SP', taker_code: 602, freight_cents: 41_667,
                                       icms_cents: 5_000)
    end
    let!(:guide_on_local_service) do
      create(:atua_transport_document, tenant:, number: '73180', cfop: 6353, origin_state: 'PR', freight_cents: 563_410, icms_cents: 56_341)
    end
    let!(:local_service) do
      create(:atua_transport_document, tenant:, number: '73181', cfop: 6353, origin_state: 'PR', freight_cents: 100_000, icms_cents: 12_000)
    end
    let!(:exempt) { create(:atua_transport_document, tenant:, number: '73182', cfop: 6932, origin_state: 'SP', icms_cents: 0) }
    let!(:canceled) do
      create(:atua_transport_document, tenant:, number: '73183', cfop: 6932, origin_state: 'SP', icms_cents: 9_000, canceled_at: Time.current)
    end
    let!(:removed) do
      create(:atua_transport_document, tenant:, number: '73184', cfop: 6932, origin_state: 'SP', icms_cents: 9_000,
                                       removed_from_atua_at: Time.current)
    end
    let!(:ce) { create(:atua_transport_document, tenant:, number: '73185', document_kind: 'ce', cfop: 6932, origin_state: 'SP', icms_cents: 9_000) }
    let!(:stranger) { create(:atua_transport_document, tenant: other_tenant, number: '73186', cfop: 6932, origin_state: 'SP', icms_cents: 9_000) }

    before do
      create(:atua_expense, tenant:, history_code: 503, history_name: 'ICMS ANTECIPADO', cost_object: paid, total_cents: 20_447)
      create(:atua_expense, tenant:, history_code: 503, history_name: 'ICMS ANTECIPADO', cost_object: divergent, total_cents: 4_000)
      create(:atua_expense, tenant:, history_code: 503, history_name: 'ICMS ANTECIPADO', cost_object: guide_on_local_service, total_cents: 12_600)
      create(:atua_expense, tenant:, history_code: 503, history_name: 'ICMS ANTECIPADO', cost_object: pending, total_cents: 8_681,
                            removed_from_atua_at: Time.current)
      create(:atua_expense, tenant:, history_code: 434, history_name: 'COMBUSTIVEL - DIESEL', cost_object: pending, total_cents: 50_000)
    end

    it 'lists the active CT-es started outside the carrier state with ICMS and the ones with an advance ICMS guide' do
      expect(tenant.atua_transport_documents.advance_icms).to contain_exactly(paid, divergent, pending, not_expected, guide_on_local_service)
    end

    it 'sums the active advance ICMS guides of each CT-e' do
      guides = tenant.atua_transport_documents.advance_icms.with_advance_icms_guide.to_h { |document| [document.number, document.advance_icms_guide.cents] }

      expect(guides).to eq('75830' => 20_447, '75831' => 4_000, '75845' => 0, '75846' => 0, '73180' => 12_600)
    end

    it 'tells whether the guide was paid, diverges from the ICMS, is pending for a group whose guides the carrier pays or is not expected' do
      documents = tenant.atua_transport_documents.advance_icms.with_advance_icms_guide.index_by(&:number)

      expect(documents.transform_values(&:advance_icms_status)).to eq(
        '75830' => :paid, '75831' => :divergent, '75845' => :pending, '75846' => :not_expected, '73180' => :divergent,
      )
      expect(documents.transform_values { |document| document.advance_icms_difference.cents }).to eq(
        '75830' => 0, '75831' => -992, '75845' => -8_681, '75846' => -5_000, '73180' => -43_741,
      )
    end

    it 'filters the CT-es by the status of the guide' do
      documents = tenant.atua_transport_documents.advance_icms

      expect(documents.by_advance_icms_status(:paid)).to contain_exactly(paid)
      expect(documents.by_advance_icms_status(:divergent)).to contain_exactly(divergent, guide_on_local_service)
      expect(documents.by_advance_icms_status(:pending)).to contain_exactly(pending)
      expect(documents.by_advance_icms_status(:not_expected)).to contain_exactly(not_expected)
    end

    it 'stops expecting the guide when the group no longer has the carrier paying it' do
      gerdau.update!(pays_advance_icms: false)

      expect(tenant.atua_transport_documents.advance_icms.by_advance_icms_status(:not_expected)).to contain_exactly(pending, not_expected)
    end

    it 'totals the CT-es by status, the ICMS and the guides' do
      expect(tenant.atua_transport_documents.advance_icms.advance_icms_totals).to eq(
        count: 5, counts: { paid: 1, divergent: 2, pending: 1, not_expected: 1 },
        icms: Money.from_cents(95_461), guide: Money.from_cents(37_047)
      )
    end

    it 'sorts the CT-es by the guide' do
      sorted = tenant.atua_transport_documents.advance_icms.with_advance_icms_guide.sorted_by(:advance_icms_guide, :desc).order(:number)

      expect(sorted.map(&:number)).to eq(%w[75830 73180 75831 75845 75846])
    end
  end

  describe '.advance_icms_overdue' do
    let!(:gerdau) { create(:customer_group, tenant:, name: 'GERDAU', pays_advance_icms_at: Time.current) }
    let!(:gerdau_customer) { create(:atua_customer, tenant:, code: 601, customer_group: gerdau) }
    let!(:old_pending) do
      create(:atua_transport_document, tenant:, number: '75845', taker_code: 601, cfop: 6932, icms_cents: 8_681,
                                       issued_at: Time.zone.local(2026, 11, 19, 8))
    end
    let!(:recent_pending) do
      create(:atua_transport_document, tenant:, number: '75846', taker_code: 601, cfop: 6932, icms_cents: 8_681,
                                       issued_at: Time.zone.local(2026, 11, 22, 8))
    end
    let!(:old_not_expected) do
      create(:atua_transport_document, tenant:, number: '75847', taker_code: 999, cfop: 6932, icms_cents: 8_681,
                                       issued_at: Time.zone.local(2026, 11, 1, 8))
    end

    it 'keeps the pending guides of CT-es issued more than 5 days ago' do
      travel_to Time.zone.local(2026, 11, 26, 9) do
        documents = tenant.atua_transport_documents.advance_icms

        expect(documents.advance_icms_overdue).to contain_exactly(old_pending)
        expect(documents.with_advance_icms_guide.index_by(&:number).transform_values(&:advance_icms_overdue?))
          .to eq('75845' => true, '75846' => false, '75847' => false)
      end
    end
  end

  describe '.advance_icms_statuses' do
    it 'maps the translated statuses to their keys' do
      expect(described_class.advance_icms_statuses).to eq(
        'Guia paga' => :paid, 'Guia divergente' => :divergent, 'Guia pendente' => :pending, 'Sem guia esperada' => :not_expected,
      )
    end
  end

  describe '.by_origin_state' do
    let!(:from_sao_paulo) { create(:atua_transport_document, tenant:, origin_state: 'SP') }
    let!(:from_parana) { create(:atua_transport_document, tenant:, origin_state: 'PR') }

    it 'keeps the CT-es started in the given state' do
      expect(tenant.atua_transport_documents.by_origin_state(' sp ')).to contain_exactly(from_sao_paulo)
    end
  end
end
