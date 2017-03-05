##
# Validates latitude and longitude
class LocationHandler
  class InvalidLocationError < StandardError; end

  def initialize(latitude:, longitude:)
    @latitude = latitude
    @longitude = longitude
  end

  def validate!
    errors = []
    unless valid_latitude?
      errors << 'Latitude must be between -90.0 and 90.0'
    end
    unless valid_longitude?
      errors << 'Longitude must be between -180.0 and 180.0'
    end
    if errors.any?
      message = errors.join('; ')
      raise InvalidLocationError, message
    end
  end

  def create_point!
    validate!
    format('POINT(%f %f)', @longitude, @latitude)
  end

  private

  def valid_latitude?
    @latitude.between?(-90.0, 90.0)
  end

  def valid_longitude?
    @longitude.between?(-180.0, 180.0)
  end
end
