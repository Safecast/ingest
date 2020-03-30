#!/usr/bin/env bash

base_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd -P )"

set -o errexit
set -o nounset
set -o pipefail

source "$base_dir"/logger.bash
configure_logger logger_test.bash

trap_exit() {
    local exit_status=$?
    if [ $exit_status -ne 0 ]; then
        log ERROR 'Something went wrong during execution. Exit status was: '"$exit_status"
    fi
    end_perf_timer entire_script
}
trap trap_exit EXIT

start_perf_timer entire_script

log INFO 'Test message'
log INFO 'Starting perf test.'
start_perf_timer test1
start_perf_timer test2
sleep 2
end_perf_timer test1
sleep 1
end_perf_timer test2
