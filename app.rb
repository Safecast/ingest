require 'grape'

module API
  module V1
    class Base < Grape::API
      version 'v1', using: :path

      post '/measurements' do
        required_keys = %w(captured_at device_id latitude longitude)
        missing_keys = required_keys - params.keys

        if missing_keys.empty?
          status 202
        else
          status 422
          { error: 'Missing required keys', detail: missing_keys }
        end
      end
    end
  end

  class Base < Grape::API
    format :json

    get '/' do
      { app: 'Safecast Ingest Shim' }
    end

    mount ::API::V1::Base
  end
end

