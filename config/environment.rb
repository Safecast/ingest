require 'ostruct'
require 'pathname'
require 'bundler'

# Load environment settings
# noinspection RubyConstantNamingConvention
Config = OpenStruct.new
Config.env = ENV['RACK_ENV'] ? ENV['RACK_ENV'].to_sym : :development
Config.root = Pathname.new(File.expand_path('../..', __FILE__))

Bundler.require(:default, Config.env)

if Config.env != :production
  require 'dotenv'
  # noinspection RubyArgCount
  Dotenv.load(
    Config.root.join('.env.local'),
    Config.root.join(".env.#{Config.env}"),
    Config.root.join('.env')
  )
end
