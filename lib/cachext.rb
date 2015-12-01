require "cachext/version"
require "faraday/error"

module Cachext
  autoload :Client, "cachext/client"
  autoload :Configuration, "cachext/configuration"
  autoload :Key, "cachext/key"
  autoload :Features, "cachext/features"
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

  def self.config
    @config ||= Configuration.new
  end

  def self.flush
    config.cache.clear
    config.redis.del "cachext:*"
  end
end
