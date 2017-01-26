class IndexMeasurementLocation < ActiveRecord::Migration[5.0]
  def change
    add_index :measurements, :location, using: :gist
  end
end
