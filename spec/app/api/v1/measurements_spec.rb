describe API::V1::Measurements, type: :api do
  context 'POST /v1/measurements' do
    context 'pre device_urn' do
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

      let(:stub_client) { double(:aws_sns_topic) }

      it 'publishes to SNS if measurements_topic_arn is provided' do
        ENV['MEASUREMENTS_TOPIC_ARN'] = 'arn:fake:topic'

        expect(Aws::SNS::Topic).to receive(:new).and_return(stub_client)
        expect(stub_client).to receive(:publish)

        post '/v1/measurements', { device: 1337 }
        expect(last_response.status).to eq 201

        ENV.delete('MEASUREMENTS_TOPIC_ARN')
      end
    end

    context 'device_urn' do
      let(:params) do
        {
          device_urn: 'pointcast:10033',
          device: 10033,
          when_captured: '2018-03-14T01:16:48Z',
          loc_lat: 37.011,
          loc_lon: 140.925,
        }
      end

      it 'returns 201 Created' do
        Measurement.destroy_all
        post '/v1/measurements', params
        expect(last_response.status).to eq 201
        expect(Measurement.count).to eq(1)
        expect(Measurement.first).to have_attributes(device_urn: 'pointcast:10033')
      end
    end
  end
end
