require 'logger'

module Workers
  class Batch
    attr_reader :interval, :logger

    def initialize(interval: nil, logger: ::Logger.new($stdout))
      @interval = interval || (ENV['WORKER_INTERVAL'] || 3600).to_i
      @logger = logger
    end

    def run
      logger.progname = self.class.to_s
      logger.info("Starting worker with #{interval} second interval")
      loop do
        work
        sleep interval
      end
    end
  end
end
