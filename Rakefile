require 'active_record'
require 'erb'
require 'yaml'

namespace :db do
  task :create do
    configurations =
      YAML.load(ERB.new(Pathname.new('./config/database.yml').read).result)
    configuration = configurations[ENV.fetch('INGEST_ENV', 'development')]
    ActiveRecord::Base.establish_connection(configuration.merge('database' => 'postgres', 'schema_search_path' => 'public'))
    ActiveRecord::Base.connection.create_database(
      configuration['database'], configuration
    )
  end

  task :migrate do
    configurations =
      YAML.load(ERB.new(Pathname.new('./config/database.yml').read).result)
    configuration = configurations[ENV.fetch('INGEST_ENV', 'development')]
    ActiveRecord::Base.establish_connection(configuration)
    version = ENV.key?('VERSION') ? ENV['VERSION'].to_i : nil
    ActiveRecord::Migrator.migrate('./db/migrate', version)
  end

  task :rollback do
    configurations =
      YAML.load(ERB.new(Pathname.new('./config/database.yml').read).result)
    configuration = configurations[ENV.fetch('INGEST_ENV', 'development')]
    ActiveRecord::Base.establish_connection(configuration)
    version = ENV.key?('VERSION') ? ENV['VERSION'].to_i : nil
    ActiveRecord::Migrator.migrate('./db/migrate', version)
  end

  task :rollback do
    configurations =
      YAML.load(ERB.new(Pathname.new('./config/database.yml').read).result)
    configuration = configurations[ENV.fetch('INGEST_ENV', 'development')]
    version = ENV.key?('VERSION') ? ENV['VERSION'].to_i : nil
    ActiveRecord::Migrator.down('./db/migrate', version)
  end
end

