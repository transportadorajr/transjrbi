module Tomtom
  Route = Data.define(:distance_meters, :travel_time_seconds) do
    def distance_km
      (distance_meters.to_d / 1000).round(2)
    end
  end
end
