require 'rails_helper'

RSpec.describe TaxHelper do
  describe '#tax_identity' do
    it 'shows the plate after the number only on a phone' do
      identity = Capybara.string(helper.tax_identity('41462', 'RHJ4E07'))

      expect(identity.text).to eq('41462 - RHJ4E07')
      expect(identity).to have_css('span.d-md-none', text: '- RHJ4E07')
    end

    it 'shows only the number when there is no plate' do
      expect(helper.tax_identity('41462', nil)).to eq('41462')
    end
  end
end
