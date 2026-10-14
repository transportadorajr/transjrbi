module Tomtom
  Place = Data.define(:latitude, :longitude, :kind, :city, :state, :formatted_address) do
    class << self
      def from_result(result)
        address = result.fetch('address', {})

        new(
          latitude: result.dig('position', 'lat'), longitude: result.dig('position', 'lon'), kind: result['type'],
          city: address['municipality'], state: address['countrySubdivisionCode'], formatted_address: address['freeformAddress']
        )
      end
    end
  end
end
