describe API::V1::Measurements, type: :api do
  let(:parsed_response) { JSON.parse(last_response.body).with_indifferent_access }
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

    context 'with a device_id param' do
      context 'without an existing device' do
        it 'sets the provided device_id anyways' do
          post '/v1/measurements', params

          measurement = Measurement.find(parsed_response[:id])
          expect(measurement.device_id).to eq(params[:device_id])
        end
      end

      context 'with an existing device' do
        let(:device) { create(:device) }
        it 'associates the measurement with the device' do
          params[:device_id] = device.numeric_id

          post '/v1/measurements', params

          measurement = Measurement.find(parsed_response[:id])
          expect(measurement.device).to eq(device)
        end
      end
    end
  end
end
