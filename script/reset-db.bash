#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd -P )"
project_dir="$script_dir"/..

errmsg() {
    IFS=' '
    printf '%s\n' "$*" 1>&2
}

trap_exit() {
    exit_status="$?"
    if [ $exit_status -ne 0 ]; then
        set +o xtrace
        errmsg 'Something went wrong during execution.'
        errmsg 'Exit status was: '"$exit_status"
    fi
}
trap trap_exit EXIT

# This script assumes that authentication, etc. has already been set
# up as per the system setup document referenced in the README.

if pgrep -f 'localhost:9292'; then
    set +o xtrace
    errmsg 'There is already a running Rack instance. Please shut it down before continuing.'
    exit 1
fi

# TODO this will only work in systems configured to sudo to postgres
# without a password, which use the postgres user, etc.
if psql -U safecast ingest-solarcast_development -c 'SELECT NULL;'; then
    sudo -u postgres dropdb ingest-solarcast_development
fi
if psql -U safecast ingest-solarcast_test -c 'SELECT NULL;'; then
    sudo -u postgres dropdb ingest-solarcast_test
fi

# Many Ruby tools assume a specific working directory... even some
# tools that claim to support a directory parameter don't work 100%
# without changing the working directory.
(
    cd "$project_dir"
    rake db:create
    rake db:structure:load

    rackup --daemonize --pid "$script_dir"/rackup.pid
)

"$script_dir"/example-data.rb

kill $(<"$script_dir"/rackup.pid)

set +o xtrace
errmsg 'Database reset to clean state.'
