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

sudo -u postgres dropdb ingest-solarcast_development
sudo -u postgres dropdb ingest-solarcast_test

# Many Ruby tools assume a specific working directory
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
