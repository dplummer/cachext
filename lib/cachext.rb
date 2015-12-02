require "cachext/version"
require "faraday/error"

module Cachext
  autoload :Client, "cachext/client"
  autoload :Configuration, "cachext/configuration"
  autoload :Features, "cachext/features"
  autoload :Key, "cachext/key"
  autoload :MissingRecord, "cachext/missing_record"
  autoload :Multi, "cachext/multi"
  autoload :Options, "cachext/options"

  def self.Key raw_key
    raw_key.is_a?(Key) ? raw_key : Key.new(raw_key)
  end

  def self.fetch raw_key, overrides = {}, &block
    client.fetch Key(raw_key), overrides, &block
  end

  def self.clear raw_key
    Key(raw_key).clear
  end

  def self.locked? raw_key
    Key(raw_key).locked?
  end

  def self.client
    @client ||= Client.new config
  end

  def self.config=(new_config)
    @config = new_config
  end

  def self.config
    @config ||= Configuration.new
  end

  def self.flush
    config.cache.clear
    config.redis.del "cachext:*"
  end

  def self.multi klass, ids, options = {}, &block
    Multi.new(config, klass, options).fetch ids, &block
  end

  def self.configure &block
    @config = Configuration.setup(&block)
  end
end
