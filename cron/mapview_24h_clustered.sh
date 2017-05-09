#!/usr/bin/env bash

# 2017-05-09 ND: Add second query and destination .json file to output
#                for `mapview_24h_clustered_devtest.sql`

source db_settings.env
psql -f mapview_schema.sql
psql -f mapview_24h_processing.sql
psql -q -f mapview_24h_clustered.sql |\
  aws s3 cp - "${EXPORT_TARGET}"/json/view24h.json \
  --acl public-read \
  --cache-control "max-age=300"
psql -q -f mapview_24h_clustered_devtest.sql |\
  aws s3 cp - "${EXPORT_TARGET}"/json/view24h_devtest.json \
  --acl public-read \
  --cache-control "max-age=300"
