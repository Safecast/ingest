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

  # To correct for https://github.com/Safecast/ingest/pull/2/files#diff-5835da67485dd547fb9545b67446cc53R7
  # Can remove after being deployed & run on prd env
  desc 'JSON parse any string measurement payloads'
  task fix_payload_escaping: :environment do
    Measurement.all.each do |m|
      if m.payload.is_a? String
        m.payload = JSON.parse(m.payload)
        m.save
      end
    end
  end
end
