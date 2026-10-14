require 'rails_helper'

RSpec.describe Atua::PurgeExpiredFilesCommand do
  context 'with downloaded files older and newer than 60 days' do
    let!(:expired) { create(:atua_import, :with_file, created_at: 61.days.ago) }
    let!(:recent) { create(:atua_import, :with_file, created_at: 10.days.ago) }

    it 'purges only the expired files and keeps the imports' do
      expect { described_class.call }.to change(ActiveStorage::Attachment, :count).by(-1)

      expect(expired.reload.file).not_to be_attached
      expect(recent.reload.file).to be_attached
      expect(Atua::Import.count).to eq(2)
    end

    it 'does nothing when run again' do
      described_class.call

      expect(described_class.call).to eq(0)
      expect(recent.reload.file).to be_attached
    end
  end
end
