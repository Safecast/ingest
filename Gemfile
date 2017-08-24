source 'https://rubygems.org'

# 64bit Amazon Linux 2016.09 v2.3.0 running Ruby 2.3 (Puma)
ruby '2.3.1'

gem 'puma'
gem 'rake'

# api
gem 'grape'
gem 'grape_logging'
gem 'active_model_serializers'

# database/orms
gem 'pg'
gem 'otr-activerecord'
gem 'activerecord-postgis-adapter'

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
  gem 'dotenv'
end
