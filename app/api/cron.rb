require 'yaml'

module API
  class Cron < Grape::API
    cattr_accessor(:script_location) { Config.root.join('cron') }
    cattr_accessor(:cron_definitions) { Config.root.join('cron.yaml') }

    helpers do
      def configured_job_names
        YAML.load_file(API::Cron.cron_definitions)['cron'].pluck('name')
      end

      def local?
        ['127.0.0.1', '::1'].include?(request.ip)
      end
    end

    resource :cron do
      desc 'Accept cron script posts from aws-sqsd'

      post do
        error!('Forbidden', 403) unless local?

        script_name = headers['X-Aws-Sqsd-Taskname']
        error!('Forbidden', 403) unless configured_job_names.include?(script_name)

        system(API::Cron.script_location.join(script_name).to_s)
        error!("Unable to run #{script_name}") unless $?.success?

        status(200)
      end
    end
  end
end
