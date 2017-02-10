class MeasurementSerializer < ActiveModel::Serializer
  attributes :id, :device_id, :payload
end
