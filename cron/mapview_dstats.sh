#!/usr/bin/env bash

trap_exit() {
    local exit_status="$?"
    local end_time="$(date -u '+%s')"
    if [ $exit_status -ne 0 ]; then
        log_err 'Something went wrong during execution of mapview_dstats. Exit status was: '"$exit_status"
    fi
    local execution_time=((end_time - start_time))
    log_err 'Total execution time was '"$execution_time"
}
trap EXIT trap_exit

configure_logger

source db_settings.env

psql -f mapview_schema.sql
psql -f mapview_dstats_processing.sql
psql -q -f mapview_dstats.sql | \
  aws s3 cp - "${EXPORT_TARGET}"/json/view_dstats.json \
  --acl public-read \
  --cache-control "max-age=60"
