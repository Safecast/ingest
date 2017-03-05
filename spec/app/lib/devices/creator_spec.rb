describe Devices::Creator do
  let(:params) do
    {
      numeric_id: 1234,
      device_type: 'solarcast',
      location_name: 'Tokyo, Japan'
    }
  end
  let(:handler) { Devices::Creator.new(params.merge(payload: params)) }

  it 'creates a device' do
    expect { handler.create! }.to change { Device.count }.by 1
  end

  it 'returns the device' do
    device = handler.create!
    expect(device).to be_a(Device)
  end

  it 'assigns the correct attributes' do
    device = handler.create!

    expect(device.numeric_id).to eq(params[:numeric_id])
    expect(device.device_type).to eq(params[:device_type])
    expect(device.location_name).to eq(params[:location_name])
    expect(device.payload.symbolize_keys).to eq(params)
  end

  context 'without location' do
    it 'does not assign a location' do
      device = handler.create!

      expect(device.location).to eq(nil)
    end
  end

  context 'with location' do
    before do
      params[:location] = { latitude: 34.995197, longitude: 135.764331 }
    end

    it 'assigns the location to the device' do
      device = handler.create!

      expect(device.location).to_not eq(nil)
    end
  end
end
