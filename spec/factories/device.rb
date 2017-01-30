FactoryGirl.define do
  factory :device do
    factory :device_in_kyoto do
      location { format('POINT(%f %f)', 135.764331, 34.995197) }
      location_name 'Japan, Kyoto, Kiyomizu-Gojo, MTRL'
      payload { { nuberic_id: 74, lat: 34.995197, lon: 135.764331 } }
    end
  end
end
