class AddIndexToPayloadServiceMd5OnMeasurements < ActiveRecord::Migration[5.0]
  def up
    execute(<<-SQL.strip_heredoc)
      CREATE INDEX measurements_payload_service_md5_index ON measurements USING BTREE ((payload->>'service_md5'))
    SQL
  end

  def down
    execute('DROP INDEX IF EXISTS measurements_payload_service_md5_index')
  end
end
