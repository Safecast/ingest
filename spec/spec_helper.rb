# load our application
ENV['RACK_ENV'] = 'test'
require File.expand_path('../../application', __FILE__)
require 'rack/test'
require 'support/factory_girl'
require 'database_cleaner'

Dir[Config.root.join('spec/support/**/*.rb')].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  config.profile_examples = 10
  config.order = :random

  config.include Rack::Test::Methods, type: :api
  config.include AppMixin, type: :api
end
