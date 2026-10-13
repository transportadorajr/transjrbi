require 'rails_helper'

RSpec.describe ResourceForm do
  describe '#save' do
    it 'creates a writable resource' do
      form = described_class.new(name: 'Fretes', slug: 'freights', writable: '1')

      expect { expect(form.save).to be(true) }.to change(Resource, :count).by(1)

      resource = Resource.last
      expect(resource.name).to eq('Fretes')
      expect(resource.slug).to eq('freights')
      expect(resource.writable).to be(true)
    end

    it 'creates a read only resource' do
      form = described_class.new(name: 'Fretes', slug: 'freights', writable: '0')

      expect(form.save).to be(true)
      expect(Resource.last.writable).to be(false)
    end

    it 'rejects a resource without a name and a slug' do
      form = described_class.new(name: '', slug: '')

      expect { expect(form.save).to be_falsey }.not_to change(Resource, :count)
      expect(form.errors[:name]).to be_present
      expect(form.errors[:slug]).to be_present
    end

    context 'when the slug is already taken' do
      let!(:existing_resource) { create(:resource, name: 'Usuários', slug: 'users') }

      it 'rejects the duplicated slug' do
        form = described_class.new(name: 'Outro', slug: existing_resource.slug)

        expect { expect(form.save).to be_falsey }.not_to change(Resource, :count)
        expect(form.errors[:slug]).to eq(['já está em uso por outro recurso'])
      end
    end

    it 'rejects a slug outside the expected format' do
      form = described_class.new(name: 'Fretes', slug: 'Meus Fretes')

      expect { expect(form.save).to be_falsey }.not_to change(Resource, :count)
      expect(form.errors[:slug]).to be_present
    end
  end

  describe '.for_resource' do
    let!(:resource) { create(:resource, name: 'Fretes', slug: 'freights', writable: true) }

    it 'updates the resource keeping its own slug available' do
      form = described_class.for_resource(resource)
      form.assign_attributes(name: 'Fretes Ativos', writable: '0')

      expect { expect(form.save).to be(true) }.not_to change(Resource, :count)

      resource.reload
      expect(resource.name).to eq('Fretes Ativos')
      expect(resource.slug).to eq('freights')
      expect(resource.writable).to be(false)
    end

    context 'when another resource already uses the slug' do
      let!(:other_resource) { create(:resource, name: 'Usuários', slug: 'users') }

      it 'rejects the slug' do
        form = described_class.for_resource(resource)
        form.assign_attributes(slug: other_resource.slug)

        expect(form.save).to be_falsey
        expect(form.errors[:slug]).to be_present
        expect(resource.reload.slug).to eq('freights')
      end
    end
  end
end
