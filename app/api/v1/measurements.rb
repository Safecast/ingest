module API
  module V1
    class Measurements < Grape::API
      resource :measurements do
        desc 'Create a measurement'
        params do
          optional :device_id, type: Integer
          optional :device, type: Integer
        end

        post do
          result = ::Measurements::Creator.new(params).create!
          
          status(201)
          body(result)
        end
      end
    end
  end
end
