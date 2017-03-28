class RemoveCapturedAndLocationColumns < ActiveRecord::Migration[5.0]
  def change
    remove_column :measurements, :captured_at
    remove_column :measurements, :location
  end
end
