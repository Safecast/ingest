class CreateMeasurements < ActiveRecord::Migration
  def change
    create_table :measurements do |t|
      t.datetime :captured_at, null: false
      t.st_point :location, geographic: true, null: false
      t.references :point, null: false
      t.json :payload, null: false

      t.timestamps
    end
  end
end
