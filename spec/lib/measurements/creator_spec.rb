require 'spec_helper'

RSpec.describe Measurements::Creator do
  describe '#create' do
    context 'when measurement is recorded and the same measurement is being uploaded from different transport' do
      before do
        json = '{"device": 1188192954, "loc_lat": 42.565, "loc_lon": -70.784, "lnd_7318u": 32, "lnd_7128ec": 14, "net_transport": "lora:0004A30B001BC6B9", "when_uploaded": "2017-03-02T00:54:37Z"}'
        described_class.new(JSON.parse(json)).create!
      end
    end

    it 'should raise an exception' do
      json = '{"device": 1188192954, "loc_lat": 42.565, "loc_lon": -70.784, "lnd_7318u": 32, "lnd_7128ec": 14, "net_transport": "lora:0004A30B001AE51D", "when_uploaded": "2017-03-02T00:54:37Z"}'
      expect { described_class.new(JSON.parse(json)).create! }
        .to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
