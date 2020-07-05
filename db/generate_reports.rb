require 'uri'
require 'cgi'
require 'rison'
require 'time'
require 'active_support/core_ext'
require 'thor'
require 'faraday'

class ReportGenerator
  def initialize(auth, base_url)
    @base_url = base_url

    @conn = Faraday.new(url: @base_url) { |f|
      f.basic_auth *auth.split(':', 2)
      f.headers['kbn-xsrf'] ='reporting'
      f.headers['Content-Type'] = 'application/json'
    }
  end

  def base_uri
    URI.parse(@base_url)
  end

  def base_query
    CGI.parse(base_uri.query)
  end

  #noinspection RubyResolve
  def base_job_params
    Rison.load(base_query['jobParams'].first)
  end

  def sort_field(job_params)
    job_params[:searchRequest][:body][:sort].first.keys.first
  end

  def range_filter(job_params, field)
    job_params[:searchRequest][:body][:query][:bool][:filter].each do |filter|
      return filter[:range] if filter[:range] && filter[:range][field]
    end
  end

  def interval
    1.month
  end

  def partitioned_job_params
    job_params = base_job_params
    field = sort_field(job_params)
    range = range_filter(job_params, field)

    start_date = DateTime.parse(range[field][:gte]).beginning_of_month
    end_date = DateTime.parse(range[field][:lte]).end_of_month

    partitions = []

    while start_date < end_date
      block_end = start_date + 1.month
      range[:service_uploaded] = {gte: start_date.iso8601, lt: block_end.iso8601}
      partitions << [start_date.iso8601, Rison.dump(job_params)]
      start_date += interval
    end

    partitions
  end

  def download(job_params)
    $stdout.sync = true
    print "Downloading report for #{job_params.first}..."
    download_path = start_report(job_params.last)['path']
    loop do
      response = @conn.get(download_path)
      if response.status != 503
        File.write("output-#{job_params.first}.csv", response.body)
        break
      end
      print '.'
      sleep 10
    end
  end

  #noinspection RubyArgCount
  def start_report(job_params)
    response = @conn.post { |req|
      req.params[:jobParams] = job_params
    }
    JSON.parse(response.body)
  end

  def run
    partitioned_job_params.each do |job_params|
      download(job_params)
    end
  end
end

class GeneratorReportCli < Thor
  default_task :generate
  desc "generate KIBANA_URL", "Generate periodic reports from given KIBANA_URL"
  option :auth

  def generate(kibana_url)
    ReportGenerator.new(options[:auth], kibana_url).run
  end
end

GeneratorReportCli.start
