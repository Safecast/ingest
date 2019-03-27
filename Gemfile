source 'https://rubygems.org'

# Puma with Ruby 2.3 running on 64bit Amazon Linux/2.8.6
ruby '2.3.8'

gem 'puma'
gem 'rake'

# api
gem 'grape'
gem 'grape_logging'
gem 'actionview', '>= 5.0.7.2'
gem 'active_model_serializers'

# database/orms
gem 'pg'
gem 'otr-activerecord'
gem 'activerecord-postgis-adapter'

# data pipeline
gem 'aws-sdk-sns', '~> 1'
gem 'aws-sdk-sqs', '~> 1'
gem 'aws-sdk-s3', '~> 1'
gem 'elasticsearch', '~> 5.0'

gem 'dotenv'
gem 'newrelic_rpm'

group :development do
  gem 'rerun'
end

group :test do
  gem 'database_cleaner'
  gem 'rack-test'
  gem 'rspec'
  gem 'rspec-json_matcher'
  gem 'shoulda-matchers'
end

group :development, :test do
  gem 'annotate'
  gem 'factory_girl'
  gem 'pry'
end
