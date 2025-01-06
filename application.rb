require_relative 'config/environment'

# Database connection
OTR::ActiveRecord.configure_from_file!(
  Config.root.join('config', 'database.yml')
)

# Load application
[
  %w(app lib *.rb),
  %w(config initializers *.rb),
  %w(config initializers ** *.rb),
  %w(app models ** *.rb),
  %w(app models *.rb),
  %w(app serializers ** *.rb),
  %w(app serializers *.rb),
  %w(app api ** *.rb),
  %w(app api *.rb),
  %w(app workers batch.rb),
  %w(app workers *.rb)
].each do |pattern|
  Dir.glob(Config.root.join(*pattern)).each { |file| require file }
end

ActiveRecord.schema_format = :sql
ActiveRecord.dump_schemas = :all

OTR::ActiveRecord.establish_connection!