require 'aws-sdk-sns'

module Measurements
  class Creator
    def initialize(payload)
      @device_id = payload[:device_id] || payload[:device]
      @device_urn = payload[:device_urn]
      @payload = payload
    end

    def create!
      params = { device_id: @device_id, payload: @payload }
      params = params.merge(device_urn: @device_urn) if @device_urn
      measurement = Measurement.create!(params)

      if ENV['MEASUREMENTS_TOPIC_ARN']
        topic = Aws::SNS::Topic.new(ENV['MEASUREMENTS_TOPIC_ARN'])
        topic.publish(message: {version: 1, payload: @payload}.to_json)
      end

      measurement
    end
  end
end
