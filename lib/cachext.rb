require "cachext/version"
require "faraday/error"
require "active_support/core_ext/module/delegation"

module Cachext
  autoload :Client, "cachext/client"
  autoload :Configuration, "cachext/configuration"

  class << self
    delegate :fetch, :backup_key, :locked?, :clear, to: :client
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
