require 'aws-sdk-sqs'
require 'aws-sdk-s3'
require 'stringio'

module Workers
  class S3Raw < Batch
    attr_reader :queue, :bucket, :object_prefix

    def initialize(input_queue_url, output_bucket_name, object_prefix, interval: nil)
      super(interval: interval)

      @queue = Aws::SQS::Queue.new(input_queue_url)
      @bucket = Aws::S3::Bucket.new(output_bucket_name)
      @object_prefix = object_prefix
    end

    def work
      key = [object_prefix, Time.now.utc.strftime('%Y-%m-%d/%H/%M')].join('/')

      write_location = "s3://#{bucket.name}/#{key}"
      logger.info("Starting batch from #{queue.url} to #{write_location}")

      count = 0
      body = StringIO.new
      1_000.times do # Getting 10_000 (1_000 * 10) messages at most.
        messages = queue.receive_messages(max_number_of_messages: 10)
        break if messages.size.zero?
        count += messages.size
        messages.each do |msg|
          body.puts(JSON.parse(msg.body).fetch('Message', ''), '')
          msg.delete
        end
      end

      if count.zero?
        logger.info('No messages to process')
        return
      end

      logger.info("Batching #{count} messages")
      bucket.put_object(key: key, body: body)
      logger.info("Wrote #{body.size} bytes to #{write_location}")
    end
  end
end
