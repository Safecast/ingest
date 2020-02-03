# File should be sourced, not executed. Do not add shebang to top.

# TODO somehwat risky to enable these in an unrelated sourced file
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
    script_tag="$1"
    # TODO if you call this twice in the same program it will cause problems
    logger_execution_id="$(uuidgen -r)"
    use_elastic="$(determine_destination_enabled elastic)"
    use_stderr="$(determine_destination_enabled stderr)"
    use_syslog="$(determine_destination_enabled syslog)"
}

log() {
    # Available log levels based on SLF4J. http://www.slf4j.org/apidocs/org/slf4j/Logger.html
    local -A levels=(['TRACE']='TRACE' ['DEBUG']='DEBUG' ['INFO']='INFO' ['WARN']='WARN' ['ERROR']='ERROR')
    local level="${levels["$1"]:?}"
    shift 1
    local IFS=' '
    if [ "$use_stderr" = 'true' ]; then
        # TODO JSON output
        printf 'tag:%s exec_id:%s level:%s message:%s\n' "$script_tag" "$logger_execution_id" "$level" "$*" 1>&2
    fi
    if [ "$use_syslog" = 'true' ]; then
        printf 'tag: %s exec_id:%s level:%s message:%s\n' "$script_tag" "$logger_execution_id" "$level" "$*" | logger -t "$script_tag"
    fi
}

create_metric() {
    # TODO implement metrics uploading
    :
}

start_perf_timer() {
    local timer_name="$1"
    local start_time="$(date -u '+%s')"
    IFS= read -r perf_start_time_"$timer_name" <<< "$start_time"
    log 'INFO' 'Starting timer '"$timer_name"' at '"$start_time"
}

end_perf_timer() {
    local timer_name="$1"
    local end_time=$(date -u '+%s')
    local start_time=${!perf_start_time_"$timer_name"}
    unset perf_start_time_"$timer_name"
    local time_diff=$(($end_time - $start_time))
    log 'INFO' 'Ending timer '"$timer_name"' at '"$end_time"
    log 'INFO' 'Execution time for '"$timer_name"' was '"$time_diff"' seconds'
    create_metric "$timer_name" "$time_diff"
}
