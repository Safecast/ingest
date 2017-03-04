module API
  module V1
    class Devices < Grape::API
      before do
        authenticate!
      end

      resource :devices do
        desc 'List devices'
        get do
          # TODO: pagination
          Device.all
        end

        route_param :id do

          desc 'Show a device'
          get do
            Device.find(params[:id])
          end
        end

        # TODO: enable when some security measurements are implemented
        # desc 'Create a device'
        # post do
          # device_params = params.select do |k, _v|
            # ::Device.valid_attributes.include?(k)
          # end
          # ::Device.create!(device_params.merge(payload: params))
          # status(201)
        # end

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
