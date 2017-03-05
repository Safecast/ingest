describe LocationHandler do
  let(:latitude) { 34.995197 }
  let(:longitude) { 135.764331 }
  let(:handler) do
    LocationHandler.new(latitude: latitude, longitude: longitude)
  end

  describe '#validate!' do
    context 'with valid latitude and longitude' do
      let(:handler) do
        LocationHandler.new(latitude: latitude, longitude: longitude)
      end

      it 'does not raise an error' do
        expect { handler.validate! }.to_not raise_error
      end
    end

    context 'with invalid latitude' do
      let(:latitude) { 110.456765 }

      it 'raises an Invalid Location error' do
        expect { handler.validate! }.to raise_error(
          LocationHandler::InvalidLocationError
        )
      end
    end

    context 'with invalid longitude' do
      let(:longitude) { 205.673352 }

      it 'raises an Invalid Location error' do
        expect { handler.validate! }.to raise_error(
          LocationHandler::InvalidLocationError
        )
      end
    end
  end

  describe '#create_point!' do
    it 'validates the location data' do
      allow(handler).to receive(:validate!)

      handler.create_point!

      expect(handler).to have_received(:validate!)
    end

    it 'creates a geography point' do
      result = handler.create_point!

      expect(result).to eq("POINT(#{longitude} #{latitude})")
    end
  end
end
