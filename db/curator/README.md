# Elasticsearch management with curator

These are some scripts used to do things like re-index the daily indices published by the elastic_cloud.rb worker.

To run them use:

```
IFS='' read -rs CURATOR_PASSWORD && export CURATOR_PASSWORD
(type or paste in password for the "elastic" user and press return. ask mat for the password)
export CURATOR_AUTH="elastic:${CURATOR_PASSWORD}"
curator --config curator.yml yearly_reindex.yml --dry-run
```

Please use caution as there's not really any "undo" for any of this stuff. We have 30m snapshots for 48hrs we could restore from but that could incur some loss of data between action & restore.

## yearly_reindex.yml

Reindexes all 2019 daily indices into a single yearly index

## yearly_delete.yml

Deletes all the 2019 daily indices. For use after reindexing.
