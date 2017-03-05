module Devices
  class Creator
    def initialize(params)
      @params = params
    end

    def create!
      location = @params.delete(:location)
      device = Device.new(@params)
      set_location(device: device, location: location) if location
      device.save!
      device
    end

    private

    def set_location(device:, location:)
      location_point = LocationHandler.new(
        latitude: location[:latitude],
        longitude: location[:longitude]
      ).create_point!
      device.location = location_point
    end
  end
end
