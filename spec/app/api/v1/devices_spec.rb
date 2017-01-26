describe API::V1::Devices, type: :api do
  context 'GET /v1/devices' do
    context 'no device' do
      before do
        get '/v1/devices'
      end

      it 'return an empty list' do
        expect(last_response.status).to eq(200)
        expect(last_response.body).to be_json_as([])
      end
    end

    context '1 device' do
      let!(:device) { create(:device_in_kyoto) }

      before do
        get '/v1/devices'
      end

      it 'return an empty list' do
        expect(last_response.status).to eq(200)
        parsed_response = JSON.parse(last_response.body)
        expect(parsed_response.size).to eq(1)
        expect(parsed_response.first).to include('id' => device.id)
      end
    end
  end

  context 'GET /v1/devices/:id' do
    let(:device) { create(:device_in_kyoto) }

    before do
      get format('/v1/devices/%d', device.id)
    end

    it 'returns a device in JSON' do
      expect(last_response.status).to eq(200)
      expect(last_response.body)
        .to be_json_including('id' => device.id)
    end
  end

  context 'POST /v1/devices' do
    it 'returns 201 Created' do
      post '/v1/devices', { id: 74 }
      expect(last_response.status).to eq(201)
      expect(::Device.find(1)).to be_a(::Device)
    end
  end

  context 'PATCH /v1/devices/:id' do
    let(:device) { create(:device_in_kyoto) }

    it 'updates device' do
      patch format('/v1/devices/%d', device.id), { 'location_name' => 'Kyoto' }
      expect(last_response.status).to eq(204)
      expect(device.reload.location_name).to eq('Kyoto')
    end
  end

  context 'DELETE /v1/devices/:id' do
    let(:device) { create(:device_in_kyoto) }

    context 'existing device' do
      before do
        delete format('/v1/devices/%d', device.id)
      end

      it 'deletes specified device' do
        expect(last_response.status).to eq(204)
        expect do
          ::Device.find(device.id)
        end.to raise_exception(::ActiveRecord::RecordNotFound)
      end
    end
  end
end
