class EnableUuid < ActiveRecord::Migration[5.0]
  def change
    enable_extension 'uuid-ossp'

    change_table :devices do |t|
      t.uuid :uuid, null: false, default: 'uuid_generate_v4()'
      t.rename :id, :numeric_id
      t.rename :uuid, :id
      t.change :numeric_id, :integer, default: nil
    end

    reversible do |dir|
      execute 'ALTER TABLE devices DROP CONSTRAINT devices_pkey;'

      dir.up do
        execute 'ALTER TABLE devices ADD PRIMARY KEY (id);'
      end

      dir.down do
        execute 'ALTER TABLE devices ADD PRIMARY KEY (numeric_id);'
      end
    end
  end
end
