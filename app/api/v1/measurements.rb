module API
  module V1
    class Measurements < Grape::API
      resource :measurements do
        desc 'Create a measurement'
        params do
          requires :captured_at, type: String
          requires :device_id, type: Integer
          requires :latitude, type: Float
          requires :longitude, type: Float
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
