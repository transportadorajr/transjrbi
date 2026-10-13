require 'rails_helper'

RSpec.describe Resource do
  describe '#translated_name' do
    context 'when the slug has a translation' do
      let!(:resource) { create(:resource, name: 'Nome Salvo', slug: 'users') }

      it 'prefers the translation of the slug' do
        expect(resource.translated_name).to eq('Usuários')
      end
    end

    context 'when the slug has no translation' do
      let!(:resource) { create(:resource, name: 'Nome Salvo', slug: 'unknown_resource') }

      it 'falls back to the stored name' do
        expect(resource.translated_name).to eq('Nome Salvo')
      end
    end
  end

  describe 'scopes' do
    let!(:users_resource) { create(:resource, name: 'Usuários', slug: 'users') }
    let!(:freight_resource) { create(:resource, name: 'Fretes', slug: 'freights') }

    it 'filters by a partial name' do
      expect(described_class.by_name('fret')).to eq([freight_resource])
    end

    it 'filters by a partial slug' do
      expect(described_class.by_slug('use')).to eq([users_resource])
    end
  end
end
