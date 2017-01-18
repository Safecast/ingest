require_relative '../defaults'

module API
  module V1
    module Defaults
      def self.included(target)
        target.include API::Defaults
      end
    end
  end
end
