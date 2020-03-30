#!/usr/bin/env bash

base_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd -P )"

set -o errexit
set -o nounset
set -o pipefail

source "$base_dir"/logger.bash
configure_logger mapview_dstats.sh

trap_exit() {
    local exit_status=$?
    if [ $exit_status -ne 0 ]; then
        log ERROR 'Something went wrong during execution. Exit status was: '"$exit_status"
    fi
    end_perf_timer entire_script
}
trap trap_exit EXIT

start_perf_timer entire_script

source "$base_dir"/db_settings.env

start_perf_timer mapview_schema.sql
psql -f mapview_schema.sql
end_perf_timer mapview_schema.sql

start_perf_timer mapview_dstats_processing.sql
psql -f mapview_dstats_processing.sql
end_perf_timer mapview_dstats_processing.sql

start_perf_timer mapview_dstats.sql_to_s3
psql -q -f mapview_dstats.sql | \
  aws s3 cp - "${EXPORT_TARGET}"/json/view_dstats.json \
  --acl public-read \
  --cache-control "max-age=60"
end_perf_timer mapview_dstats.sql_to_s3
