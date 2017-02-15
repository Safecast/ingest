class CreateMeasurements < ActiveRecord::Migration[5.0]
  def change
    enable_extension 'postgis'

    create_table :measurements do |t|
      t.datetime :captured_at, null: false
      t.st_point :location, geographic: true, null: false
      t.integer :device_id, null: false
      t.json :payload, null: false

      t.timestamps null: false
    end
  end
end
