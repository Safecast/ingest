require 'aws-sdk-sns'

module Measurements
  class Creator
    def initialize(payload)
      @device_id = payload[:device_id] || payload[:device]
      @payload = payload
    end

    def create!
      measurement = Measurement.create!(
        device_id: @device_id,
        payload: @payload
      )

      if ENV['MEASUREMENTS_TOPIC_ARN']
        topic = Aws::SNS::Topic.new(ENV['MEASUREMENTS_TOPIC_ARN'])
        topic.publish(message: {version: 1, payload: @payload}.to_json)
      end

      measurement
    end
  end
end
