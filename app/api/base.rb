require 'grape/active_model_serializers'
require_relative 'v1/base'
require_relative 'cron'

module API
  class Base < Grape::API
    include Grape::ActiveModelSerializers

    format :json
    use Grape::Middleware::Globals
    use GrapeLogging::Middleware::RequestLogger, logger: logger

    mount API::V1::Base
    mount API::Cron
  end
end
