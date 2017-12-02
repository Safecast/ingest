require 'aws-sdk-sqs'
require 'aws-sdk-s3'

module Workers
  class S3Raw < Batch
    attr_reader :queue, :bucket, :object_prefix

    # Need to protect against this
    # Aws::SQS::Errors::InternalError: We encountered an internal error. Please try again.
    #   /var/app/current/app/workers/s3_raw.rb:41:in `block in work'
    #   /var/app/current/app/workers/s3_raw.rb:41:in `each'
    #   /var/app/current/app/workers/batch.rb:16:in `block in run'
    #   /var/app/current/app/workers/batch.rb:15:in `loop'
    #   /var/app/current/app/workers/batch.rb:15:in `run'
    #   /var/app/current/Rakefile:39:in `block (2 levels) in <top (required)>'

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

      batched_messages = []
      loop do
        messages = queue.receive_messages(max_number_of_messages: 10)
        batched_messages += messages.to_a
        break if messages.size == 0 || batched_messages.size > 10_000
      end

      if batched_messages.empty?
        logger.info('No messages to process')
      else
        logger.info("Batching #{batched_messages.size} messages")

        body = batched_messages.map { |message|
          JSON.parse(message.body)['Message']
        }.join("\n\n")

        bucket.put_object(key: key, body: body)
        logger.info("Wrote #{body.size} bytes to #{write_location}")

        batched_messages.each { |m| m.delete }
      end
    end
  end
end
