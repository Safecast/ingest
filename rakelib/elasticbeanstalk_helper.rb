# frozen_string_literal: true

require 'aws-sdk-elasticbeanstalk'

class ElasticBeanstalkHelper
  attr_reader :elasticbeanstalk
  attr_reader :application_name, :environment_prefix, :environment_config

  def initialize(application_name, environment_prefix, environment_config = nil)
    if environment_config == nil
      environment_config = (ENV['AWS_EB_CFG'] || 'dev')
    end
    @application_name = application_name
    @environment_prefix = environment_prefix
    @environment_config = environment_config
    @elasticbeanstalk = Aws::ElasticBeanstalk::Client.new
  end

  def platform_arn
    minor_ruby_version = RUBY_VERSION.split('.')[0..1].join('.')
    elasticbeanstalk.list_platform_versions(filters: [
      { type: 'PlatformName',
        operator: 'begins_with',
        values: ["Puma with Ruby #{minor_ruby_version}"] },
      { type: 'PlatformVersion',
        operator: '=',
        values: ['latest'] }
    ]).platform_summary_list.first.platform_arn
  end

  def selected_environments
    environments = elasticbeanstalk.describe_environments(application_name: application_name).environments
    environment_names = environments.map(&:environment_name)
    environment_names.select { |n| n =~ /^#{environment_prefix}-#{environment_config}-/ }
  end

  def current_environment_number(tier)
    if selected_environments.empty?
      0
    else
      if tier == 'wrk'
        environment_names = selected_environments.select { |n| n =~ /-wrk-\d{3}$/}
      else
        environment_names = selected_environments.select { |n| n !~ /-wrk-\d{3}$/}
      end
      if environment_names.size != 1
        STDERR.puts('Error: More than one matching environment was found. Not sure which one is current.')
        STDERR.puts(environment_names)
        exit 1
      end
      environment_names[0].split('-').last.to_i
    end
  end

  def next_environment_number
    all_numbers = (1..999).to_a
    environment_numbers = selected_environments.map { |n| n.split('-').last.to_i }
    puts all_numbers
    puts environment_numbers
    available_numbers = all_numbers - environment_numbers
    available_numbers.min
  end

  def environment_name(number, tier = nil)
    formatted_number = format('%03d', number)

    if tier == 'wrk'
      [environment_prefix, environment_config, 'wrk', formatted_number].join('-')
    else
      [environment_prefix, environment_config, formatted_number].join('-')
    end
  end

  def eb_config(tier = nil)
    if tier == 'wrk'
      environment_config + '-wrk'
    else
      environment_config
    end
  end

  def create_command(tier = nil)
    %w(eb create) + [
      '--cfg', eb_config(tier),
      environment_name(next_environment_number, tier)
    ]
  end

  def ssh_command(tier = nil)
    %w(eb ssh) + [environment_name(current_environment_number(tier), tier)]
  end

  def deploy_command(tier = nil)
    %w(eb deploy) + [environment_name(current_environment_number(tier), tier)]
  end
end
