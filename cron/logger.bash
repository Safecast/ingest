# This file should be sourced, not executed. Do not add shebang to top.

# Usage:
#
# Most users will only need to use the log(), start_perf_timer(), and
# stop_perf_timer() functions.
#
# log <LEVEL> <MESSAGE>
# start_perf_timer <TIMER NAME>
# stop_perf_timer <TIMER NAME>

# TODO somehwat risky to enable these in an unrelated, sourced file
set -o errexit
set -o nounset
set -o pipefail

command_exists() {
    if command -v "$1" > /dev/null 2>&1; then
        printf 'true\n'
    else
        printf 'false\n'
    fi
}

validate_log_level() {
    # Available log levels based on SLF4J. http://www.slf4j.org/apidocs/org/slf4j/Logger.html
    # Global associative arrays can be buggy, which is why this is declared here.
    local -A log_levels=(['TRACE']='TRACE' ['DEBUG']='DEBUG' ['INFO']='INFO' ['WARN']='WARN' ['ERROR']='ERROR')
    if [ -z "${log_levels["$1"]:-}" ]; then
        printf 'Error: Log level %s is not understood, please remove it from your program.\n' 1>&2
        exit 64
    fi
}

determine_destination_enabled() {
    local dest_name="$1"
    local -A dest_bin_arr=(
        ['elastic']='curl'
        ['stderr']='printf'
        ['syslog']='logger'
    )
    dest_bin="${dest_bin_arr["$dest_name"]:?}"
    local -A user_var_arr=(
        ['elastic']='SAFECAST_INGEST_USE_ELASTIC_METRICS'
        ['stderr']='SAFECAST_INGEST_USE_STDERR_LOG'
        ['syslog']='SAFECAST_INGEST_USE_SYSLOG'
    )
    user_var="${user_var_arr["$dest_name"]:?}"

    bin_exists="$(command_exists "$dest_bin")"
    IFS= read -r "$user_var" <<< "${!user_var:-true}"

    use_dest='false'
    if [ "$bin_exists" = 'true' ]; then
        IFS= read -r "$user_var" <<< "${!user_var:-true}"
    else
        IFS= read -r "$user_var" <<< "${!user_var:-false}"
    fi
    if [ "$bin_exists" = 'true' ] \
           && [ "${!user_var}" = 'true' ]; then
        use_dest='true'
    elif [ "${!user_var}" = 'true' ]; then
        printf "User requested use of syslog in variable $user_var. However, the necessary $dest_bin binary cannot be found in the \$PATH. Exiting.\n" 1>&2
        exit 64
    fi

    printf '%s\n' "$use_dest"
}

configure_logger() {
    if ! [ "$(command_exists jq)" = 'true' ]; then
        printf 'This logger requires the jq binary to be installed. It is available in most package managers. See https://stedolan.github.io/jq/\n' 1>&2
        exit 1
    fi

    if [ -v script_tag ]; then
        log WARN 'The logger has already been configured. Please do not call configure_logger more than once.'
        return
    fi

    declare -gA start_times

    script_tag="$1"
    script_tag_json_string="$(printf '%s' "$script_tag" | jq --compact-output --slurp --raw-input --monochrome-output)"
    local logger_execution_id="$(uuidgen -r)"
    logger_execution_id_json_string="$(printf '%s' "$logger_execution_id" | jq --compact-output --slurp --raw-input --monochrome-output)"
    use_elastic="$(determine_destination_enabled elastic)"
    use_stderr="$(determine_destination_enabled stderr)"
    use_syslog="$(determine_destination_enabled syslog)"
}

generate_log_json() {
    local IFS=' '
    local level="$1"
    validate_log_level "$level"
    shift 1
    local message="$(printf '%s' "$*" | jq --compact-output --slurp --raw-input --monochrome-output)"
    printf '{"tag":%s, "exec_id":%s, "level":"%s", "message":%s}' \
           "$script_tag_json_string" "$logger_execution_id_json_string" "$level" "$message" \
        | jq --compact-output --monochrome-output --sort-keys
}

write_log() {
    local line="$1"
    if [ "$use_stderr" = 'true' ]; then
        cat 1>&2 <<< "$line"
    fi
    if [ "$use_syslog" = 'true' ]; then
        logger -t "$script_tag" <<< "$line"
    fi
}

log() {
    write_log "$(generate_log_json $*)"
}

create_metric() {
    # TODO implement metrics uploading
    :
}

start_perf_timer() {
    local timer_name="$1"
    local start_time="$(date -u '+%s')"
    # TODO verify variable does not already exist
    start_times["$timer_name"]="$start_time"
    local standard_log="$(generate_log_json INFO 'Starting timer '"$timer_name"' at '"$start_time")"
    local timer_name_json_string="$(printf '%s' "$timer_name" | jq --compact-output --slurp --raw-input --monochrome-output)"
    local additional_log="$(printf '{"perf_event":"START","perf_start_time":%s, "perf_timer_name":%s}' "$start_time" "$timer_name_json_string")"
    write_log "$(printf '[%s, %s]' "$standard_log" "$additional_log" | jq --compact-output --monochrome-output --sort-keys '.[0] + .[1]')"
}

end_perf_timer() {
    local timer_name="$1"
    local end_time=$(date -u '+%s')
    local start_time=${start_times["$timer_name"]}
    # TODO unset
    local time_diff=$(($end_time - $start_time))
    log 'INFO' 'Ending timer '"$timer_name"' at '"$end_time"
    log 'INFO' 'Execution time for '"$timer_name"' was '"$time_diff"' seconds'
    create_metric "$timer_name" "$time_diff"
}
