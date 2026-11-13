require 'rails_helper'

RSpec.describe RevenueProjectionDayNoteForm do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant:) }

  before { travel_to(Time.zone.local(2026, 11, 4, 10)) }

  describe '#save' do
    it 'writes the note of a closed day with its author' do
      form = described_class.new(tenant:, user:, date: Date.new(2026, 11, 2), body: '  Greve no porto  ')

      expect { expect(form.save).to be(true) }.to change(RevenueProjection::DayNote, :count).by(1)

      expect(RevenueProjection::DayNote.last).to have_attributes(tenant:, user:, date: Date.new(2026, 11, 2), body: 'Greve no porto')
    end

    it 'rewrites the note of the day with the new author' do
      note = create(:revenue_projection_day_note, tenant:)
      form = described_class.new(tenant:, user:, date: note.date, body: 'Chuva na usina')

      expect { expect(form.save).to be(true) }.not_to change(RevenueProjection::DayNote, :count)

      expect(note.reload).to have_attributes(body: 'Chuva na usina', user:)
    end

    it 'erases the note when the body is left blank' do
      note = create(:revenue_projection_day_note, tenant:)

      expect { expect(described_class.new(tenant:, user:, date: note.date, body: ' ').save).to be(true) }
        .to change(RevenueProjection::DayNote, :count).by(-1)
    end

    it 'does not fail when erasing a day without a note' do
      expect(described_class.new(tenant:, user:, date: Date.new(2026, 11, 2), body: '').save).to be(true)
    end

    it 'rejects a day that has not ended and a note over the size limit' do
      form = described_class.new(tenant:, user:, date: Date.new(2026, 11, 4), body: 'a' * 501)

      expect { expect(form.save).to be_falsey }.not_to change(RevenueProjection::DayNote, :count)
      expect(form.errors.full_messages).to contain_exactly('Dia não pode ser um dia que ainda não terminou',
                                                           'Anotação é muito longo (máximo: 500 caracteres)')
    end
  end

  it 'loads the note of the day' do
    create(:revenue_projection_day_note, tenant:, body: 'Greve no porto')

    expect(described_class.for_date(tenant, Date.new(2026, 11, 2))).to have_attributes(body: 'Greve no porto', to_param: '2026-11-02')
  end
end
