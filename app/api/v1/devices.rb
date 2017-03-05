module API
  module V1
    class Devices < Grape::API
      before do
        authenticate!
      end

      resource :devices do
        rescue_from ::LocationHandler::InvalidLocationError do |e|
          error!(e, 422)
        end

        desc 'List devices'
        get do
          # TODO: pagination
          Device.all
        end

        desc 'Create a device'
        params do
          requires :device, type: Hash do
            requires :numeric_id, type: Integer
            requires :device_type, type: String, values: Device.available_types
            optional :location_name
            optional :location, type: Hash do
              requires :latitude, type: Float
              requires :longitude, type: Float
            end
          end
        end
        post do
          device_params = declared(params, include_missing: false).device

          if device_params.location
            LocationHandler.new(
              latitude: device_params.location[:latitude],
              longitude: device_params.location[:longitude]
            ).validate!
          end

          ::Devices::Creator.new(
            device_params.merge(payload: device_params)
          ).create!
        end

        route_param :id do

          desc 'Show a device'
          get do
            Device.find(params[:id])
          end
        end

        # desc 'Update a device'
        # patch ':id' do
          # device = ::Device.find(params[:id])
          # params.delete(:id)
          # device_params = params.select do |k, _v|
            # ::Device.valid_attributes.include?(k)
          # end
          # device.update!(device_params.merge(payload: params))
          # status(204)
        # end

        # desc 'Delete a device'
        # delete ':id' do
          # device = ::Device.find(params[:id])
          # device.destroy!
        # end
      end
    end
  end
end
