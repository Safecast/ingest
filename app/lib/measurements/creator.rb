module Measurements
  class Creator
    def initialize(payload)
      @captured_at = payload.delete(:captured_at).to_datetime
      @device_id = payload.delete(:device_id)
      @location = generate_location(payload.extract!(:longitude, :latitude).symbolize_keys)
      @payload = payload
    end

    def create!
      Measurement.create!(
        captured_at: @captured_at,
        device_id: @device_id,
        location: @location,
        payload: @payload
      )
    end

    def generate_location(longitude:, latitude:)
      "POINT(#{longitude} #{latitude})"
    end
  end
end
