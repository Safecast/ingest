class AddDeviceIdIndices < ActiveRecord::Migration[5.2]
  def change
    add_index :measurements, :device_id
    add_index :measurements, :device_urn
  end
end
