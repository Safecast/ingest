class CorrectPayloadType < ActiveRecord::Migration[5.0]
  def change
    change_column :measurements, :payload, :jsonb
  end
end
