# Safecast Ingest API

This is a new ingest API for safecast data.

Basic goals are:

- support arbitrary fields with measurement data
- allow for API versioning

## Requirements

* Ruby, see `Gemfile` for version
* Postgres with postgis running locally
* A `safecast` superuser on that local postgres server

See [Dev: Setup on OS X](https://github.com/Safecast/safecastapi/wiki/Dev:-Setup-on-OS-X) or one of the related "Dev:" pages for specific info.

## Setting up for dev work

Once you have the requirements installed try running this:

```
bundle install
rake db:create
rake db:structure:load
rake
```

If all goes well you should see a green line like `6 examples, 0 failures` indicating the tests have passed.

You can then run this to start the server:

```
rerun rackup
```

And run this to post some example data into your local server via curl:

```
./script/example_data.sh
```

And run this to get a ruby console:

```
bundle exec irb -r./application
```

Or this to run a db console:

```
psql -U safecast ingest-solarcast_development
```
