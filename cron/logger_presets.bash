# This file should be sourced, not executed. Do not add shebang to top.

test_for_boolean_string() {
    if [ "${!1:-x}" = 'x' ] \
           || ([ "$1" != 'true' ] && [ "$1" != 'false' ]); then
        printf '%s\n' "Variable $1 must be set to either 'true' or 'false'." 1>&2
        return 1
    fi
    return 0
}

export SAFECAST_SH_LOGGER_ENV="${SAFECAST_SH_LOGGER_ENV:-custom}"

if [ "$SAFECAST_SH_LOGGER_ENV" = 'development' ] \
       || [ "$SAFECAST_SH_LOGGER_ENV" = 'test' ]; then
    export SAFECAST_SH_LOGGER_USE_ELASTIC_METRICS="${SAFECAST_SH_LOGGER_USE_ELASTIC_METRICS:-false}"
    export SAFECAST_SH_LOGGER_USE_STDERR_LOG="${SAFECAST_SH_LOGGER_USE_STDERR_LOG:-true}"
    export SAFECAST_SH_LOGGER_USE_SYSLOG="${SAFECAST_SH_LOGGER_USE_SYSLOG:-false}"
elif [ "$SAFECAST_SH_LOGGER_ENV" = 'staging' ] \
         || [ "$SAFECAST_SH_LOGGER_ENV" = 'production' ]; then
    export SAFECAST_SH_LOGGER_USE_ELASTIC_METRICS="${SAFECAST_SH_LOGGER_USE_ELASTIC_METRICS:-true}"
    export SAFECAST_SH_LOGGER_USE_STDERR_LOG="${SAFECAST_SH_LOGGER_USE_STDERR_LOG:-false}"
    export SAFECAST_SH_LOGGER_USE_SYSLOG="${SAFECAST_SH_LOGGER_USE_SYSLOG:-true}"
else
    logger_variables=(SAFECAST_SH_LOGGER_USE_ELASTIC_METRICS SAFECAST_SH_LOGGER_USE_STDERR_LOG SAFECAST_SH_LOGGER_USE_SYSLOG)
    error_found='false'
    for var_name in "${logger_variables[@]}"; do
        if ! test_for_boolean_string "$var_name"; then
            error_found='true'
        fi
    done
    if [ "$error_found"='true' ]; then
        printf '%s\n' 'Error: If the SAFECAST_SH_LOGGER_ENV variable is not set to a valid value, then all of the variables listed above must be set to either true or false. Alternatively, set SAFECAST_SH_LOGGER_ENV to get defaults. See logger_presets.bash for more information.' 1>&2
        exit 64
    fi
fi
