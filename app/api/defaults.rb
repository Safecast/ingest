module API
  module Defaults
    def self.included(target)
      handle_param_errors(target)
      handle_other_errors(target)
    end

    def self.handle_param_errors(target)
      target.class_eval do
        rescue_from Grape::Exceptions::ValidationErrors do |e|
          error!(e, 400)
        end
      end
    end

    def self.handle_other_errors(target)
      target.class_eval do
        rescue_from :all do |e|
          error!(
            { message: "rescued from #{e.class.name}, #{e.backtrace}" },
            500,
            { 'Content-Type' => 'text/json' },
            e.backtrace
          )
        end
      end
    end
  end
end
