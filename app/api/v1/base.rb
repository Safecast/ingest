require_relative 'defaults'
require_relative 'devices'
require_relative 'measurements'

module API
  module V1
    class Base < Grape::API
      include API::V1::Defaults

      version 'v1'

      helpers Authentication

      mount API::V1::Devices
      mount API::V1::Measurements
    end
  end
end
