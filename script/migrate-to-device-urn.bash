#!/usr/bin/env bash

errmsg() {
    IFS=' '
    printf '%s\n' "$*" 1>&2
}

errmsg 'Total count of rows that contain a device_id but no device_urn:'
psql safecast 'SELECT count(device_id) FROM measurements WHERE device_urn IS NULL;' 1>&2

errmsg 'Total count of unique device_ids that need backpopulation:'
psql safecast 'SELECT count(DISTINCT device_id) FROM measurements WHERE device_urn IS NULL;' 1>&2

errmsg 'Count of unique device_ids in need of backpopulation where there is no known device_urn (these will require investigation):'
psql safecast 'SELECT count(*) FROM measurements WHERE device_urn IS NULL AND device_id NOT IN (SELECT DISTINCT device_id FROM measurements WHERE device_urn IS NOT NULL);' 1>&2

errmsg 'Count of unique device_urns that have exactly one corresponding device_id, and that device_id needs backpopulation (these are the ones that will be easy to backpopulate):'
psql safecast 'WITH distinct_pairs AS ( SELECT DISTINCT device_id, device_urn FROM measurements WHERE device_urn IS NOT NULL) SELECT count(*) FROM distinct_pairs WHERE count(device_id) = 1 AND device_id IN (SELECT DISTINCT device_id FROM measurements WHERE device_urn IS NULL) GROUP BY device_urn;' 1>&2

errmsg 'Count of unique device_urns that have more than one corresponding device_id in need of backpopulation (these will require more investigation):'
psql safecast 'WITH distinct_pairs AS ( SELECT DISTINCT device_id, device_urn FROM measurements WHERE device_urn IS NOT NULL) SELECT count(*) FROM distinct_pairs WHERE count(device_id) = 1 AND device_id IN (SELECT DISTINCT device_id FROM measurements WHERE device_urn IS NULL) GROUP BY device_urn;' 1>&2
