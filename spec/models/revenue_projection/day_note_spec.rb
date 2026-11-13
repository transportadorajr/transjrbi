require 'rails_helper'

RSpec.describe RevenueProjection::DayNote do
  it 'requires the day and a body within the size limit' do
    note = build(:revenue_projection_day_note, date: nil, body: 'a' * 501)

    expect(note).not_to be_valid
    expect(note.errors.attribute_names).to contain_exactly(:date, :body)
  end

  it 'stores a single note per day of each tenant' do
    note = create(:revenue_projection_day_note)

    expect { create(:revenue_projection_day_note, tenant: note.tenant, user: note.user) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
