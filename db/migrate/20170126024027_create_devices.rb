class CreateDevices < ActiveRecord::Migration[5.0]
  def change
    create_table :devices do |t|
      t.st_point :location, geographic: true, null: true
      t.string :location_name, null: true
      t.jsonb :payload, null: false

      t.timestamps null: false
    end
  end
end
