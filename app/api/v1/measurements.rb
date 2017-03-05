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
          ::Measurements::Creator.new(params).create!
        end
      end
    end
  end
end
