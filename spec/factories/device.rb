FactoryGirl.define do
  factory :device do
    factory :device_in_kyoto do
      payload {
        {
          numeric_id: 74,
          lat: 34.995197,
          lon: 135.764331,
          location_name: 'Japan, Kyoto, Kiyomizu-Gojo, MTRL'
        }
      }
      numeric_id { payload[:numeric_id] }
      location { format('POINT(%f %f)', payload[:lon], payload[:lat]) }
      location_name { payload[:location_name] }
    end
  end
end
