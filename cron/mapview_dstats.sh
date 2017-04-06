#!/usr/bin/env bash

source db_settings.env
psql -f mapview_schema.sql
psql -f mapview_dstats_processing.sql
psql -q -f mapview_dstats.sql |\
  aws s3 cp - "${EXPORT_TARGET}"/json/view_dstats.json \
  --acl public-read \
  --cache-control "max-age=60"
