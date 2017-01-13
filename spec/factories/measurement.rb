FactoryGirl.define do
  factory :measurement do
    captured_at { DateTime.current }
    device_id 12345678
    location 'POINT(-70.78382 42.564835)'
    payload do
      { lora_snr: 7, lndp_cpm: 25, transport: 'http:50.250.38.70:46306' }
    end
  end
end
