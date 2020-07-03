require 'uri'
require 'cgi'
require 'rison'
require 'time'
require 'active_support/core_ext'

user = "mat"
password = "..."

post_url = "https://5bc3d4f7330a4459881197a85659caf5.us-west-2.aws.found.io:9243/api/reporting/generate/csv?jobParams=(conflictedTypesFields:!(),fields:!(service_uploaded,when_captured,device_urn,device_sn,device,loc_lat,loc_lon,env_temp,env_humid,pms_pm01_0,pms_pm02_5,pms_pm10_0,lnd_7318c,lnd_7318u,bat_voltage),indexPatternId:%27ingest-measurements-*%27,metaFields:!(_source,_id,_type,_index,_score),searchRequest:(body:(_source:(excludes:!(),includes:!(service_uploaded,when_captured,device_urn,device_sn,device,loc_lat,loc_lon,env_temp,env_humid,pms_pm01_0,pms_pm02_5,pms_pm10_0,lnd_7318c,lnd_7318u,bat_voltage)),docvalue_fields:!((field:service_uploaded,format:date_time)),query:(bool:(filter:!((bool:(filter:!((bool:(must_not:(bool:(minimum_should_match:1,should:!((match:(dev_test:!t))))))),(bool:(minimum_should_match:1,should:!((query_string:(fields:!(device_sn),query:%27*%5C3%5C0%5C0*%27)))))))),(range:(service_uploaded:(format:strict_date_optional_time,gte:%272018-06-02T15:41:00.909Z%27,lte:%272019-02-03T14:12:43.638Z%27)))),must:!(),must_not:!(),should:!())),script_fields:(),sort:!((service_uploaded:(order:desc,unmapped_type:boolean))),stored_fields:!(service_uploaded,when_captured,device_urn,device_sn,device,loc_lat,loc_lon,env_temp,env_humid,pms_pm01_0,pms_pm02_5,pms_pm10_0,lnd_7318c,lnd_7318u,bat_voltage),version:!t),index:%27ingest-measurements-*%27),title:%27DataKind%20export%27,type:search)"

parsed_url = URI.parse(post_url)
#noinspection RubyResolve
job_params = Rison.load(CGI.parse(parsed_url.query)['jobParams'].first)
parsed_url.query = nil

range = job_params[:searchRequest][:body][:query][:bool][:filter][1][:range]
start_date = DateTime.parse(range[:service_uploaded][:gte]).beginning_of_month
end_date = DateTime.parse(range[:service_uploaded][:lte]).end_of_month

queries = []

while start_date < end_date
  block_end = start_date + 1.month
  range[:service_uploaded] = {gte: start_date.iso8601, lt: block_end.iso8601}
  queries << Rison.dump(job_params)
  start_date += 1.month
end

pp urls
