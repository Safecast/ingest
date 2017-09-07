#!/usr/bin/env bash

set -euxo pipefail

INGEST_ENV="${1:-local}"

case "${INGEST_ENV}" in
  local)
    URL=http://localhost:9292
    ;;
  dev)
    URL=http://ingest-dev.safecast.cc
    ;;
  prd)
    URL=https://ingest.safecast.org
    ;;
  *)
    echo "Unknown ingest environment ${INGEST_ENV}"
    exit 1
esac

curl -v \
  -H'Content-Type: application/json' \
  -d'{"captured_at":"2017-01-23T00:50:18Z","device_id":1337,"latitude":42.564835,"longitude":-70.78382,"lora_snr":5,"lndc_cpm":13,"transport":"http:50.250.38.70:37661"}' \
  "${URL}/v1/measurements"

