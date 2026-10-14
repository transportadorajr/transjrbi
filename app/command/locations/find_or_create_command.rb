module Locations
  class FindOrCreateCommand
    ADDRESS_KINDS = ['Point Address', 'Address Range', 'Street'].freeze

    class << self
      def call(street:, city:, state:, client: nil)
        new(street:, city:, state:, client:).call
      end
    end

    def initialize(street:, city:, state:, client: nil)
      @street = street.to_s.squish.presence
      @city = city.to_s.squish.presence
      @state = state.to_s.squish.upcase.presence
      @client = client
    end

    def call
      return if city.blank? || state.blank?

      Location.find_by(lookup_key:) || create_location
    end

    private

    attr_reader :street, :city, :state

    def lookup_key
      Location.lookup_key_for(street:, city:, state:)
    end

    def create_location
      street ? create_address_location : create_city_location
    end

    def create_address_location
      place = client.geocode([street, city, state].join(', ')).find { |candidate| matches?(candidate) && ADDRESS_KINDS.include?(candidate.kind) }
      return save(place, :address) if place

      city_location = self.class.call(street: nil, city:, state:, client:)
      city_location && save(city_location, :city)
    end

    def create_city_location
      place = client.geocode([city, state].join(', '), municipality: true).find { |candidate| matches?(candidate) }
      save(place, :city) if place
    end

    def matches?(place)
      Location.normalize(place.city) == Location.normalize(city) && Location.normalize(place.state) == state
    end

    def save(place, precision_type)
      Location.create!(
        lookup_key:, street:, city:, state:, latitude: place.latitude, longitude: place.longitude, precision_type:,
        formatted_address: place.formatted_address
      )
    rescue ActiveRecord::RecordNotUnique
      Location.find_by!(lookup_key:)
    end

    def client
      @client ||= Tomtom::Client.new
    end
  end
end
