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

# TODO this one isn't right
errmsg 'Count of unique device_ids that have exactly one corresponding device_urn, and that device_id needs backpopulation (these are the ones that will be easy to backpopulate):'
$psql_cmd '' 1>&2

errmsg 'Count of unique device_ids in need of backpopulation where there is no known device_urn (these will require investigation):'
$psql_cmd 'SELECT count(DISTINCT device_id) FROM measurements WHERE device_urn IS NULL AND device_id NOT IN (SELECT DISTINCT device_id FROM measurements WHERE device_urn IS NOT NULL);' 1>&2

errmsg 'Count of unique device_urns that have more than one corresponding device_id, and at least one of those device_ids needs backpopulation (these will require investigation):'
$psql_cmd 'SELECT count(DISTINCT device_urn) FROM (SELECT device_urn, count(DISTINCT device_id) AS device_id_count FROM measurements WHERE device_urn IS NOT NULL AND device_id IN (SELECT DISTINCT device_id FROM measurements WHERE device_urn IS NULL) GROUP BY device_urn) AS t WHERE t.device_id_count > 1;' 1>&2

errmsg 'Count of unique device_ids in need of backpopulation that have more than one corresponding device_urn (these will require investigation):'
$psql_cmd 'SELECT count(DISTINCT device_id) FROM (SELECT device_id, count(DISTINCT device_urn) AS device_urn_count FROM measurements WHERE device_urn IS NOT NULL AND device_id IN (SELECT DISTINCT device_id FROM measurements WHERE device_urn IS NULL) GROUP BY device_id) AS t WHERE t.device_urn_count > 1;' 1>&2

errmsg 'Last time that a new row was inserted that did not have a device_urn:'
$psql_cmd 'SELECT created_at FROM measurements ORDER BY created_at DESC LIMIT 1;'
