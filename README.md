# Cachext

Extensions to normal Rails caching:

* Lock
* Backup

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cachext'
```

And then execute:

    $ bundle

## Usage

Replace `Rails.cache.fetch` with `Cachext.fetch`.

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

