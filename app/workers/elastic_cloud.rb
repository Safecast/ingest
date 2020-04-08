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
              '@timestamp'=>{'type'=>'date'},
              'bat_charge'=>{'type'=>'float'},
              'bat_current'=>{'type'=>'float'},
              'bat_voltage'=>{'type'=>'float'},
              'dev_comms_failures'=>{'type'=>'long'},
              'dev_comms_resets'=>{'type'=>'long'},
              'dev_free_memory'=>{'type'=>'long'},
              'dev_humid'=>{'type'=>'float'},
              'dev_last_failure'=>{'type'=>'keyword', 'ignore_above'=>1024},
              'dev_motion'=>{'type'=>'boolean'},
              'dev_motion_events'=>{'type'=>'long'},
              'dev_ntp_count'=>{'type'=>'long'},
              'dev_oneshot_seconds'=>{'type'=>'long'},
              'dev_oneshots'=>{'type'=>'long'},
              'dev_press'=>{'type'=>'float'},
              'dev_received_bytes'=>{'type'=>'long'},
              'dev_restarts'=>{'type'=>'long'},
              'dev_temp'=>{'type'=>'float'},
              'dev_test'=>{'type'=>'boolean'},
              'dev_transmitted_bytes'=>{'type'=>'long'},
              'dev_uptime'=>{'type'=>'long'},
              'device'=>{'type'=>'long'},
              'device_class'=>{'type'=>'keyword', 'ignore_above'=>1024},
              'device_sn'=>{'type'=>'keyword', 'ignore_above'=>1024},
              'device_urn'=>{'type'=>'keyword', 'ignore_above'=>1024},
              'env_humid'=>{'type'=>'float'},
              'env_press'=>{'type'=>'float'},
              'env_temp'=>{'type'=>'float'},
              'gateway_lora_snr'=>{'type'=>'long'},
              'gateway_received'=>{'type'=>'keyword', 'ignore_above'=>1024},
              'ingest'=>{'properties'=>{'location'=>{'type'=>'geo_point','ignore_malformed'=>true}}},
              'lnd_7128ec'=>{'type'=>'float'},
              'lnd_712u'=>{'type'=>'float'},
              'lnd_7318c'=>{'type'=>'float'},
              'lnd_7318u'=>{'type'=>'float'},
              'lnd_78017w'=>{'type'=>'float'},
              'loc_alt'=>{'type'=>'float'},
              'loc_country'=>{'type'=>'keyword', 'ignore_above'=>1024},
              'loc_lat'=>{'type'=>'float'},
              'loc_lon'=>{'type'=>'float'},
              'loc_name'=>{'type'=>'keyword', 'ignore_above'=>1024},
              'loc_olc'=>{'type'=>'keyword', 'ignore_above'=>1024},
              'loc_zone'=>{'type'=>'keyword', 'ignore_above'=>1024},
              'opc_c00_38'=>{'type'=>'long'},
              'opc_c00_54'=>{'type'=>'long'},
              'opc_c01_00'=>{'type'=>'long'},
              'opc_c02_10'=>{'type'=>'long'},
              'opc_c05_00'=>{'type'=>'long'},
              'opc_c10_00'=>{'type'=>'long'},
              'opc_csecs'=>{'type'=>'float'},
              'opc_pm01_0'=>{'type'=>'float'},
              'opc_pm02_5'=>{'type'=>'float'},
              'opc_pm10_0'=>{'type'=>'float'},
              'pms2_c00_30'=>{'type'=>'long'},
              'pms2_c00_50'=>{'type'=>'long'},
              'pms2_c01_00'=>{'type'=>'long'},
              'pms2_c02_50'=>{'type'=>'long'},
              'pms2_c05_00'=>{'type'=>'long'},
              'pms2_c10_00'=>{'type'=>'long'},
              'pms2_csamples'=>{'type'=>'long'},
              'pms2_csecs'=>{'type'=>'float'},
              'pms2_model'=>{'type'=>'keyword', 'ignore_above'=>1024},
              'pms2_pm01_0'=>{'type'=>'float'},
              'pms2_pm02_5'=>{'type'=>'float'},
              'pms2_pm10_0'=>{'type'=>'float'},
              'pms_c00_30'=>{'type'=>'long'},
              'pms_c00_50'=>{'type'=>'long'},
              'pms_c01_00'=>{'type'=>'long'},
              'pms_c02_50'=>{'type'=>'long'},
              'pms_c05_00'=>{'type'=>'long'},
              'pms_c10_00'=>{'type'=>'long'},
              'pms_csamples'=>{'type'=>'long'},
              'pms_csecs'=>{'type'=>'float'},
              'pms_model'=>{'type'=>'keyword', 'ignore_above'=>1024},
              'pms_pm01_0'=>{'type'=>'float'},
              'pms_pm02_5'=>{'type'=>'float'},
              'pms_pm10_0'=>{'type'=>'float'},
              'pms_std01_0'=>{'type'=>'float'},
              'service_handler'=>{'type'=>'keyword', 'ignore_above'=>1024},
              'service_md5'=>{'type'=>'keyword', 'ignore_above'=>1024},
              'service_transport'=>{'type'=>'keyword', 'ignore_above'=>1024},
              'service_uploaded'=>{'type'=>'date'},
              'when_captured'=>{'type'=>'date'},
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
