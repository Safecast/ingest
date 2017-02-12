module API
  module V1
    class Measurements < Grape::API
      resource :measurements do
        desc 'Create a measurement'
        params do
          requires :device_id, type: Integer
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
