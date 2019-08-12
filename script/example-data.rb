#!/usr/bin/env ruby

require 'csv'
require 'net/http'

# Not making it easy to use this with staging/production environments
# as right now much of the data is indistinguishable from real data
api_uri = URI('http://localhost:9292/v1/measurements')

File.open(File.join(File.expand_path(File.dirname(__FILE__)), 'example-data.csv')) { |data_file|
  data_csv = CSV.new(data_file, :col_sep => "\t", :quote_char => nil)
  data_csv.each do |row|
    Net::HTTP.post(api_uri, row[2], 'Content-Type' => 'application/json')
  end
}
