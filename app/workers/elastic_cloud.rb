require 'elasticsearch'
require 'aws-sdk-sqs'

module Workers
  class ElasticCloud
    attr_reader :input_queue_url, :output_cluster_url, :index_prefix, :document_type, :logger

    def initialize(input_queue_url, output_cluster_url,
                   index_prefix: 'ingest-measurements',
                   document_type: '_doc',
                   logger: ::Logger.new($stdout))
      @input_queue_url = input_queue_url
      @output_cluster_url = output_cluster_url
      @index_prefix = index_prefix
      @document_type = document_type
      @logger = logger
      @logger.progname = self.class.to_s
    end

    def run
      logger.info("Starting real-time worker from #{input_queue_url} to #{output_cluster_uri.host}")
      setup_cluster

      poller = Aws::SQS::QueuePoller.new(input_queue_url)
      poller.poll do |message|
        body = JSON.parse(message.body)
        logger.info("Got message timestamped #{body['Timestamp']}")

        parsed_message = JSON.parse(body['Message'])
        logger.debug("Message version was #{parsed_message['version']}")

        payload = parsed_message['payload']

        now = Time.now.utc
        payload['@timestamp'] = payload['when_captured'] || payload['service_uploaded'] || now.iso8601
        index_suffix = now.strftime('%Y-%m-%d')

        payload['ingest'] = {}

        if payload.include?('loc_lat') && payload.include?('loc_lon')
            payload['ingest']['location'] = {
                lat: payload['loc_lat'],
                lon: payload['loc_lon']
            }
        end

        begin
          result = client.index(
              index: "#{index_prefix}-#{index_suffix}",
              type: document_type,
              body: payload
          )

          logger.info("Wrote #{result}")
        rescue Elasticsearch::Transport::Transport::Error => e
          logger.error("Unable to save measurement: #{e.message}")
          raise e
        end
      end
    end

    def setup_cluster
      client.indices.put_template(
          name: index_prefix,
          body: {
              template: index_prefix + '-*',
              order: 0,
              settings: {
                  number_of_shards: 1,
                  number_of_replicas: 1
              },
              mappings: {
                  _meta: {
                      version: '1.0.0'
                  },
                  date_detection: false,
                  dynamic_templates: [
                      {
                          strings_as_keyword: {
                              mapping: {
                                  ignore_above: 1024,
                                  type: 'keyword'
                              },
                              match_mapping_type: 'string'
                          }
                      }
                  ],
                  properties: {
                      :@timestamp => {
                          type: 'date'
                      },
                      service_uploaded: {
                          type: 'date'
                      },
                      :'ingest.location' => {
                          type: 'geo_point',
                          ignore_malformed: true
                      },
                      pms_std01_0: {
                          type: 'float'
                      }
                  }
              }
          }
      )
    end

    def output_cluster_uri
      URI.parse(output_cluster_url)
    end

    def client
      @client ||= Elasticsearch::Client.new log: true, url: output_cluster_uri
    end
  end
end
