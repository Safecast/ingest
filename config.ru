require_relative 'application'

use OTR::ActiveRecord::ConnectionManagement

run Rack::Cascade.new([API::Base])
