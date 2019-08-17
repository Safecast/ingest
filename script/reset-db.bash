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
    if [ -f "$script_dir"/rackup.pid ]; then
        kill $(<"$script_dir"/rackup.pid) || true
    fi
    if [ $exit_status -ne 0 ]; then
        set +o xtrace
        errmsg 'Something went wrong during execution.'
        errmsg 'Exit status was: '"$exit_status"
    fi
}
trap trap_exit EXIT

print_help() {
    set +o xtrace
    errmsg 'Options:'
    errmsg '-d <path>: Read ingest data from the file given. Mutually exclusive with -n.'
    errmsg '-h: Print this help message.'
    errmsg '-n: Do not pre-populate any data. Mutually exclusive with -d.'
    set -o xtrace
}

data_file=''
populate_data='true'
while getopts ":d:n" opt; do
    case $opt in
        d)
            data_file="$OPTARG"
            ;;
        h)
            print_help
            exit 0
            ;;
        n)
            populate_data='false'
            ;;
        \?)
            errmsg "Invalid option: -$OPTARG"
            print_help
            exit 64
            ;;
    esac
done

# Validate parameters
if [ "$populate_data" != 'true' ] && [ -n "$data_file" ]; then
    errmsg 'Error: -d and -n cannot be specified at the same time.'
    errmsg
    print_help
    exit 64
fi

# This script assumes that authentication, etc. has already been set
# up as per the system setup document referenced in the README.

if pgrep -f 'localhost:9292'; then
    set +o xtrace
    errmsg 'There is already a running Rack instance. Please shut it down before continuing.'
    exit 1
fi

# Many Ruby tools assume a specific working directory... even some
# tools that claim to support a directory parameter don't work 100%
# without changing the working directory.
(
    cd "$project_dir"
    rake db:drop:all
    rake db:create
    rake db:structure:load

    rackup --daemonize --pid "$script_dir"/rackup.pid
)

if [ "$populate_data" = 'true' ]; then
    if [ -n "$data_file" ]; then
        "$script_dir"/example-data.rb -d "$data_file"
    else
        "$script_dir"/example-data.rb
    fi
fi

set +o xtrace
errmsg 'Database reset to clean state.'
