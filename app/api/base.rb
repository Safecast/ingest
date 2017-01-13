require 'grape/active_model_serializers'
require './app/api/v1/base'

module API
  class Base < Grape::API
    include Grape::ActiveModelSerializers

    prefix :api
    format :json
    use Grape::Middleware::Globals

    mount API::V1::Base
  end
end
