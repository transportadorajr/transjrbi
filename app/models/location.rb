class Location < ApplicationRecord
  PRECISIONS = %i[address city].freeze
  KEY_SEPARATOR = '|'.freeze
  PUNCTUATION = /[^A-Z0-9 ]/

  enum :precision_type, PRECISIONS.index_with(&:to_s), prefix: :precision, validate: true

  validates :lookup_key, presence: true, uniqueness: true
  validates :city, :state, :latitude, :longitude, presence: true

  class << self
    def lookup_key_for(street:, city:, state:)
      [street, city, state].map { |part| normalize(part) }.join(KEY_SEPARATOR)
    end

    def normalize(value)
      I18n.transliterate(value.to_s).upcase.gsub(PUNCTUATION, ' ').squish
    end
  end

  def canonical
    self.class.where(latitude:, longitude:).order(:id).first || self
  end

  def same_place?(other)
    latitude == other.latitude && longitude == other.longitude
  end
end

# == Schema Information
#
# Table name: locations
#
#  id                :bigint           not null, primary key
#  city              :string           not null
#  formatted_address :string
#  latitude          :decimal(10, 7)   not null
#  longitude         :decimal(10, 7)   not null
#  lookup_key        :string           not null
#  precision_type    :enum             not null
#  state             :string           not null
#  street            :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_locations_on_latitude_and_longitude  (latitude,longitude)
#  index_locations_on_lookup_key              (lookup_key) UNIQUE
#
