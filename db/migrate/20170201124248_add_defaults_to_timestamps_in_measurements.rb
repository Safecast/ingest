class AddDefaultsToTimestampsInMeasurements < ActiveRecord::Migration[5.0]
  def up
    change_table :measurements do |t|
      %i(created_at updated_at).each do |col|
        t.change col, :datetime, null: true, default: -> { 'now()' }
      end
    end

    execute <<-SQL
      CREATE OR REPLACE FUNCTION update_updated_at_column()
      RETURNS TRIGGER AS $$
      BEGIN
        NEW.updated_at = now();
        RETURN NEW;
      END;
      $$ language 'plpgsql';
    SQL

    execute <<-SQL
      CREATE TRIGGER update_measurements_updated_at
      BEFORE UPDATE ON measurements
      FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
    SQL
  end

  def down
    execute 'DROP TRIGGER IF EXISTS update_measurements_updated_at ON measurements;'
    execute 'DROP FUNCTION IF EXISTS update_updated_at_column();'
    change_table :measurements do |t|
      %i(created_at updated_at).each do |col|
        t.change col, :datetime, null: false
      end
    end
  end
end
