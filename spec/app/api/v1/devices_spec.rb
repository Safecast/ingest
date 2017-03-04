describe API::V1::Devices, type: :api do
  let(:api_key) { 'API_KEY' }
  before do
    allow(Config)
      .to receive(:api_key)
      .and_return(api_key)
  end

  context 'GET /v1/devices' do
    context 'with invalid authentication' do
      it 'returns 401' do
        remove_auth

        get '/v1/devices'

        expect(last_response.status).to eq(401)
      end
    end

    context 'with valid authentication' do
      before do
        add_auth(api_key)
      end

      context 'with no existing devices' do
        before do
          get '/v1/devices'
        end

        it 'returns 200 OK' do
          expect(last_response.status).to eq(200)
        end

        it 'return an empty list' do
          expect(parsed_response).to eq([])
        end
      end

      context 'with one existing device' do
        let(:device) { create(:device_in_kyoto) }
        before do
          device
          get '/v1/devices'
        end

        it 'returns 200 OK' do
          expect(last_response.status).to eq(200)
        end

        it 'returns one device' do
          expect(parsed_response.size).to eq(1)
          expect(parsed_response.first['id']).to eq(device.id)
        end
      end
    end
  end

  context 'GET /v1/devices/:id' do
    let(:device) { create(:device_in_kyoto) }

    context 'with invalid authentication' do
      it 'returns 401 Unauthorized' do
        remove_auth

        get "/v1/devices/#{device.id}"

        expect(last_response.status).to eq(401)
      end
    end

    context 'with valid authentication' do
      before do
        add_auth(api_key)
        get format('/v1/devices/%s', device.id)
      end

      it 'returns 200 OK' do
        expect(last_response.status).to eq(200)
      end

      it 'returns JSON format' do
        expect(last_response.body).to be_json
      end

      it 'returns the correct device' do
        expect(parsed_response['id']).to eq(device.id)
      end
    end
  end
end
