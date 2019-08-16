#!/usr/bin/env ruby

require 'csv'
require 'json'
require 'net/http'

api_uris = {
  'local' => URI('http://localhost:9292/v1/measurements'),
  'dev' => URI('http://ingest-dev.safecast.cc/v1/measurements'),
  'prd' => URI('https://ingest.safecast.org'),
}

data_file = File.join(File.expand_path(File.dirname(__FILE__)), 'example-data.jsonl')

ingest_env = 'local'
if ARGV.length == 1
  ingest_env = ARGV[0]
elsif ARGV.length > 1
  STDERR.puts('You have passed more than one argument on the command line. Only one argument is accepted: the name of a known environment.')
  exit(64)
end

if ! api_uris.key?(ingest_env)
  STDERR.puts('You have passed an unknown environment name. The value must be one of the following:')
  STDERR.puts(api_uris.keys.to_json())
  exit(64)
end

api_uri = api_uris[ingest_env]

Net::HTTP.start(api_uri.hostname, api_uri.port,
                :use_ssl => api_uri.scheme == 'https' ) {|http|
  # Why jsonl? See http://jsonlines.org/
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
