module Measurements
  class Creator
    def initialize(payload)
      @device_id = payload[:device_id] || payload[:device]
      @payload = payload
    end

    def create!
      Measurement.create!(
        device_id: @device_id,
        payload: @payload
      )
    end
  end
end
