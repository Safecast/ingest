FactoryBot.define do
  factory :measurement do
    device_id { 12345678 }
    payload do
      { lora_snr: 7, lndp_cpm: 25, transport: 'http:50.250.38.70:46306' }
    end
  end
end
