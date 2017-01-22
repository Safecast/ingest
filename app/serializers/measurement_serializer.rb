class MeasurementSerializer < ActiveModel::Serializer
  attributes :id, :captured_at, :device_id, :location, :payload

  def location
    { longitude: object.location.x, latitude: object.location.y }
  end
end
