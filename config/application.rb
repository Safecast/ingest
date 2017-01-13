env = ENV.fetch('RACK_ENV', :development).to_sym
root = Pathname.new(File.expand_path('../..', __FILE__))

require 'bundler'
Bundler.require(:default, env)

OTR::ActiveRecord.configure_from_file! root.join('config/database.yml')
