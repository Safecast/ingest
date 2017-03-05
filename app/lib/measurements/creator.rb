module Measurements
  class Creator
    def initialize(payload)
      @device_id = payload[:device_id] || payload[:device]
      @captured_at = payload[:captured_at].try(:to_datetime)
      @payload = payload
    end

    def create!
      Measurement.create!(
        device_id: @device_id,
        captured_at: @captured_at,
        payload: @payload
      )
    end
  end
end
