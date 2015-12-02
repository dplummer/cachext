# Cachext

[![Build Status](https://travis-ci.org/dplummer/cachext.svg)](https://travis-ci.org/dplummer/cachext)
[![Gem Version](https://badge.fury.io/rb/cachext.svg)](https://badge.fury.io/rb/cachext)

Extensions to normal Rails caching:

* Lock (inspired by https://github.com/seamusabshere/lock_and_cache)
* Backup

## Quickstart

```ruby
Cachext.config.cache = Rails.cache
Cachext.config.redis = Redis.current

key = [:foo, :bar, 1]
Cachext.fetch key, expires_in: 2.hours, default: "cow" do
  Faraday.get "http://example.com/foo/bar/1"
end
```

* Other services making the same call at the same time will wait for the
  first to complete, so only 1 call is made in a 2 hour window
* A backup of the value is stored too, so if the service raises a
  Faraday::Error::ConnectionFailed we'll return the backup
* If no backup exists but we got a ConnectionFailed, we'll return the default
  of "cow"

```ruby
Record = Struct.new :id
Cachext.multi [:foo, :bar], [1,2,3], expires_in: 5.minutes do |ids|
  data = JSON.parse Faraday.get("http://example.com/foo/bar?ids=#{ids.join(',')}")
  data.each_with_object({}) do |record, acc|
    acc[record["id"]] = Record.new record["id"]
  end
end
# => { 1 => Record.new(1), 2 => Record.new(2), 3 => Record.new(3) }
```

* The passed block will be called with the ids that were not available in the
  cache. The return value of the block should either be a hash with keys of
  ids, or an array of objects that have `id` methods.
* In the event of a server error (ie `ConnectionFailed`), backup values are
  used.

## Configuration options

```ruby
Cachext.config.cache = Rails.cache
```

`Cachext` expects a cache store that has the `ActiveSupport::Cache` interface,
so that can be Memcache, Redis, FileStore, etc.

```ruby
Cachext.config.redis = Redis.current
```

`Cachext` uses redis for locking (the
[Redlock](https://github.com/leandromoreira/redlock-rb) gem under the hood), so
we need at least Redis 2.8.

```ruby
Cachext.config.raise_errors = false
Cachext.config.default_errors = [
  Faraday::Error::ConnectionFailed,
  Faraday::Error::TimeoutError,
]
```

By default `Cachext` will not re-raise the standard default errors. Setting
this to `true` is helpful in a test environment. The `default_errors` are those
caught as transient issues that a backup will be used for.

```ruby
Cachext.config.not_found_errors = [Faraday::Error::ResourceNotFound]
```

If a NotFound exception is raised, the backup is *not* used, and any backup
that exists will be deleted. Then the exception will be re-raised.

```ruby
Cachext.config.default_expires_in = 60 # in seconds
```

The default TTL for values fetched. Only used for the "fresh" cache, not the
backup (which has no TTL).

```ruby
Cachext.config.max_lock_wait = 5 # in seconds
```

The most we'll wait for a lock to unlock. If it takes more than this value to
get a lock (due to another service holding the lock while making the call),
we'll fallback to the backup value.

```ruby
Cachext.config.debug = ENV['CACHEXT_DEBUG'] == "true"
```

If `debug` is set to `true` (or you run your program/test with
`CACHEXT_DEBUG=true`), you'll get lots of debug messages around the locking and
whats going on. Very helpful for debugging :)

```ruby
Cachext.config.heartbeat_expires = 2 # in seconds
```

If a process that holds a lock crashes, other processes will have to wait this
many seconds for the lock to expire.

```ruby
Cachext.config.error_logger = nil
```

If set to an object that responds to call, will `call` with any errors caught.

## Usage

```ruby
Cachext.fetch key, options, &block
```

Available options:

* `expires_in`: override for the `default_expires_in`, in seconds
* `default`: object or proc that will be used as the default if no backup is found
* `errors`: override for the `default_errors` to be caught
* `reraise_errors`: default `true`, if set to `false` NotFound errors will not
  be raised
* `not_found_error`: override for `not_found_errors`
* `heartbeat_expires`: override for `heartbeat_expires`

```ruby
Cachext.multi key_base, ids, options, &block
```

Available options:

* `expires_in`: override for `default_expires_in`, in seconds
* `return_array`: return an array instead of a hash. Will include missing
  records as `Cachext::MissingRecord` objects so you can deal with them.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake spec` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

Having trouble with a test? Set the `CACHEXT_DEBUG` environmental variable to
"true" to get debug logs.

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/dplummer/cachext.

## License

The gem is available as open source under the terms of the
[MIT License](http://opensource.org/licenses/MIT).

