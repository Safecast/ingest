describe API::V1::Measurements, type: :api do
  context 'POST /v1/measurements' do
    let(:params) do
      {
        captured_at: '2017-01-13T05:56:35Z',
        device_id: 1553490618,
        latitude: 42.564835,
        longitude: -70.78382,
        lora_snr: 7,
        lndp_cpm: 25,
        transport: 'http:50.250.38.70:46306'
      }
    end

    it 'returns 201 Created' do
      post '/v1/measurements', params
      expect(last_response.status).to eq 201
    end

    it 'returns the created measurement' do
      post '/v1/measurements', params
      parsed_response = JSON.parse(last_response.body).with_indifferent_access
      expect(parsed_response[:device_id]).to eq(params[:device_id])
    end

    it 'accepts minimal params' do
      post '/v1/measurements', { device_id: 1337 }
      expect(last_response.status).to eq 201
    end

    it 'accepts device as a device_id key' do
      post '/v1/measurements', { device: 1337 }
      expect(last_response.status).to eq 201
    end

  end
end
