
#!/usr/bin/env bash

source db_settings.env
psql -f mapview_24h_clustered.sql | aws s3 cp - "${EXPORT_TARGET}"/json/view24h.json