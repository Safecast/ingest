#!/usr/bin/env bash

set -ex

curl -v \
  -H'Content-Type: application/json' \
  -d'{"captured_at":"2017-01-23T00:50:18Z","device_id":1553490618,"latitude":42.564835,"longitude":-70.78382,"lora_snr":5,"lndc_cpm":13,"transport":"http:50.250.38.70:37661"}' \
  http://localhost:9292/v1/measurements

