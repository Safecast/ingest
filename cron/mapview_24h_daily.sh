#!/usr/bin/env bash

today_str="$(date '+%Y %m %d %H %M %S')"
yesterday_str="$(date -v -1d '+%Y %m %d %H %M %S')"

at=( $today_str )
ay=( $yesterday_str )

source db_settings.env
psql -f mapview_schema.sql
psql -q -f mapview_24h_daily.sql -v v1="'"${at[0]}"-"${at[1]}"-"${at[2]}"T"${at[3]}":"${at[4]}":"${at[5]}"Z'" |\
  aws s3 cp - "${EXPORT_TARGET}"/json/daily/"${at[0]}"/"${at[1]}"/"${at[2]}".json \
  --acl public-read \
  --cache-control "max-age=300"

psql -q -f mapview_24h_daily.sql -v v1="'"${ay[0]}"-"${ay[1]}"-"${ay[2]}"T"${ay[3]}":"${ay[4]}":"${ay[5]}"Z'" |\
  aws s3 cp - "${EXPORT_TARGET}"/json/daily/"${ay[0]}"/"${ay[1]}"/"${ay[2]}".json \
  --acl public-read \
  --cache-control "max-age=300"

