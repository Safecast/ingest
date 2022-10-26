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

Reindexes all 2021 daily indices into a single yearly index

## yearly_delete.yml

Deletes all the 2021 daily indices. For use after reindexing.

## Data massaging

When we change data mapping during the year, you may run into cases where you can't reindex old data into the new mappings.

The main example so far was `when_captured` which was dynamic initially, then changed to a date. So some older indices failed to reindex with errors like this if they contained an invalid date:

```
failed to parse date field [1998-19-250T04:35:59Z] with format [strict_date_optional_time||epoch_millis]
```

(note the month 19 there)

One technique to work around this is search and delete. For example:

```
POST ingest-measurements-2021-*/_search
{
  "query": {
    "bool": {
      "filter": {
        "script": {
          "script": {
            "lang": "painless",
            "source": """
              if (doc['when_captured'].size() > 0 && doc['when_captured'].value instanceof String) {
                Integer.parseInt(doc['when_captured'].value.splitOnToken('-')[1]) > 12;
              } else {
                false
              }
            """
          }
        }
      }
    }
  }
}
```

This will find any documents with string `when_captured` values with a month greater than 12.

You can then replace the `_search` with `_delete_by_query` to remove the documents.

If you've already marked the indices as read-only you need to remove that lock before deletion.

```
PUT ingest-measurements-2021-*/_settings
{
  "index.blocks.read_only": null
}
```
