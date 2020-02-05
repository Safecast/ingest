#!/usr/bin/env bash

source logger.bash
configure_logger logger_test.bash
log INFO 'Test message'
log INFO 'Starting perf test.'
start_perf_timer test1
start_perf_timer test2
sleep 2
end_perf_timer test1
sleep 1
end_perf_timer test2
