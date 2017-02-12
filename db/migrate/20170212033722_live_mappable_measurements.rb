class LiveMappableMeasurements < ActiveRecord::Migration[5.0]
  def up
    execute <<-SQL
      drop materialized view if exists mappable_measurements;
      create view mappable_measurements
      as select
        id,
        created_at,
        updated_at,
        device_id,
        (payload->>'captured_at')::timestamptz at time zone 'UTC' as captured_at,
        POINT((payload->>'latitude')::numeric, (payload->>'longitude')::numeric) as location,
        payload
      from measurements
      where
        payload->>'latitude' is not null and
        payload->>'longitude' is not null and
        payload->>'captured_at' is not null;
    SQL
  end

  def down
    execute <<-SQL
      drop view if exists mappable_measurements
    SQL
  end
end
