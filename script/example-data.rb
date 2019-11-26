#!/usr/bin/env ruby

require 'csv'
require 'json'
require 'net/http'
require 'optparse'

Options = Struct.new(:api_uri, :data_file, :ingest_env)
class Parser
  @@api_uris = {
    'local' => URI('http://localhost:9292/v1/measurements'),
    'dev' => URI('http://ingest-dev.safecast.cc/v1/measurements'),
    'prd' => URI('https://ingest.safecast.org'),
  }
  
  def self.parse(options)
    args = Options.new("world")
    args.api_uri = @@api_uris['local']
    args.data_file = File.join(File.expand_path(File.dirname(__FILE__)), 'example-data.jsonl')
    args.ingest_env = 'local'

    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{__FILE__} [options]"

      opts.on('-d', '--data-file PATH', 'JSONL file containing the measurements to POST. See http://jsonlines.org/ for format.') do |data_file_arg|
        if File.file?(data_file_arg)
          args.data_file = File.new(data_file_arg)
        else
          STDERR.puts("Error: file #{data_file_arg} does not exist.")
          exit(64)
        end
      end

      opts.on('-e', '--ingest-environment ENV_NAME', "Name of the environment. Valid environments: #{@@api_uris.keys.to_json()}") do |ingest_env_arg|
        if ! @@api_uris.key?(ingest_env_arg)
          STDERR.puts('You have passed an unknown environment name. The value must be one of the following:')
          STDERR.puts(@@api_uris.keys.to_json())
          exit(64)
        end
        args.api_uri = @@api_uris[ingest_env_arg]
        args.ingest_env = ingest_env_arg
      end

      opts.on('-h', '--help', 'Prints this help') do
        STDERR.puts(opts)
        exit(0)
      end
    end

    opt_parser.parse!(options)
    return args
  end
end
options = Parser.parse(ARGV)

api_uri = options.api_uri
data_file = options.data_file

Net::HTTP.start(api_uri.hostname, api_uri.port,
                :use_ssl => api_uri.scheme == 'https' ) {|http|
  File.foreach(data_file).with_index { |line, line_num|
    begin
      parsed_measurement = JSON.parse(line)
    rescue
      STDERR.puts("Problem parsing the JSON object on line #{line_num}")
      exit(1)
    end

    parsed_measurement['dev_test'] = true

    response = http.post(api_uri, parsed_measurement.to_json(), 'Content-Type' => 'application/json')
    if ! response.instance_of?(Net::HTTPCreated)
      STDERR.puts("Problem posting the JSON object on line #{line_num}, response was:")
      STDERR.puts(response)
      exit(1)
    end
  }
}
