class AddDeviceUrnToMeasurements < ActiveRecord::Migration[5.0]
  def change
    add_column :measurements, :device_urn, :string
  end
end
