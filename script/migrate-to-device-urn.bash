#!/usr/bin/env bash

# The purpose of this script is to backpopulate the device_urn column
# as documented in issue 540. This is one step in migrating from
# device_id to device_urn as the primary device identifier.

errmsg() {
    IFS=' '
    printf '%s\n' "$*" 1>&2
}

psql_cmd='psql -U safecast ingest-solarcast_development -c'

errmsg 'Total count of rows that contain a device_id but no device_urn and need backpopulation:'
$psql_cmd 'SELECT count(device_id) FROM measurements WHERE device_urn IS NULL;' 1>&2

errmsg 'Total count of unique device_ids that need backpopulation:'
$psql_cmd 'SELECT count(DISTINCT device_id) FROM measurements WHERE device_urn IS NULL;' 1>&2

errmsg 'Count of unique device_urns that have exactly one corresponding device_id, and that device_id needs backpopulation (these are the ones that will be easy to backpopulate):'
$psql_cmd 'SELECT count(*) FROM (SELECT device_urn, count(device_id) AS device_id_count FROM measurements WHERE device_urn IS NULL AND device_id IN (SELECT DISTINCT device_id FROM measurements WHERE device_urn IS NOT NULL) GROUP BY device_urn) AS t WHERE t.device_id_count = 1;' 1>&2

errmsg 'Count of unique device_ids in need of backpopulation where there is no known device_urn (these will require investigation):'
$psql_cmd 'SELECT count(*) FROM measurements WHERE device_urn IS NULL AND device_id NOT IN (SELECT DISTINCT device_id FROM measurements WHERE device_urn IS NOT NULL);' 1>&2

errmsg 'Count of unique device_urns that have more than one corresponding device_id in need of backpopulation (these will require investigation):'
$psql_cmd 'SELECT count(*) FROM (SELECT device_urn, count(device_id) AS device_id_count FROM measurements WHERE device_urn IS NULL AND device_id IN (SELECT DISTINCT device_id FROM measurements WHERE device_urn IS NOT NULL) GROUP BY device_urn) AS t WHERE t.device_id_count > 1;' 1>&2
