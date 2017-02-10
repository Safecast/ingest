class RelaxMeasurementRequirements < ActiveRecord::Migration[5.0]
  def change
    change_column_null :measurements, :captured_at, true
    change_column_null :measurements, :location, true
  end
end
