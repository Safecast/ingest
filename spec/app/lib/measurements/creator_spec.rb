describe Measurements::Creator do
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
  let(:handler) { Measurements::Creator.new(params) }

  it 'creates a measurement' do
    expect { handler.create! }.to change { Measurement.count }.by 1
  end

  it 'returns the measurement' do
    measurement = handler.create!
    expect(measurement).to be_a(Measurement)
  end

  it 'assigns the correct attributes' do
    measurement = handler.create!
    puts measurement.inspect
    expect(measurement.captured_at).to eq(params[:captured_at])
    expect(measurement.device_id).to eq(params[:device_id])
    expect(measurement.payload.symbolize_keys).to eq(params)
  end

  context 'with a device_id param' do
    context 'without an existing device' do
      it 'sets the provided device_id anyways' do
        measurement = handler.create!

        expect(measurement.device_id).to eq(params[:device_id])
      end
    end

    context 'with an existing device' do
      let(:device) { create(:device) }
      it 'associates the measurement with the device' do
        params[:device_id] = device.numeric_id

        measurement = handler.create!

        expect(measurement.device).to eq(device)
      end
    end
  end
end
