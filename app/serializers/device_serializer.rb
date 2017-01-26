class DeviceSerializer < ActiveModel::Serializer
  attributes *%i(id location location_name payload created_at updated_at)

  def location
    { longitude: object.location.x, latitude: object.location.y }
  end
end
