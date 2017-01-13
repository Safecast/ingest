require 'bundler/setup'

load 'tasks/otr-activerecord.rake'

begin
  require 'annotate'
  Annotate.set_defaults(
    position_in_class: :after,
    exclude_tests: true,
    exclude_fixtures: true,
    exclude_factories: true,
    exclude_serializers: true
  )
  Annotate.load_tasks
rescue LoadError
end

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
  task default: :spec
rescue LoadError
end

task :environment do
  require_relative 'application'
end

namespace :db do
  task :environment do
    require_relative 'application'
  end
end

