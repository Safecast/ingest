describe Workers::ElasticCloud do
  let(:es_url) { 'http://localhost:9200' }
  let(:index_prefix) { 'spec-ingest-measurements' }
  let(:es_client) { Elasticsearch::Client.new log: true, url: es_url }

  subject {
    Workers::ElasticCloud.new(
      'https://sqs.us-west-2.amazonaws.com/985752656544/ingest-measurements-to-elasticcloud-test',
      es_url,
      index_prefix: index_prefix,
      idle_timeout: 0
    )
  }

  describe("run") {
    before {
      Aws.config[:sqs] = {
        stub_responses: {
          receive_message: [
            { messages: [
              { message_id: 'id1', receipt_handle: 'rh1',
                body: {
                  'Timestamp': Time.now.utc.iso8601,
                  'Message': {
                    'version': 1,
                    'payload': {
                      'foo': 'bar'
                    }
                  }.to_json
                }.to_json }
            ] },
            { messages: [] }
          ]
        }
      }
      es_client.indices.delete(index: index_prefix + '-*')
    }

    it("should process messages") {
      subject.run
      expect { es_client.count(index: index_prefix + '-*')['count'] }.to eventually eq 1
    }
  }
end
