require "cachext/version"
require "faraday/error"
require "cachext/client"
require "cachext/configuration"
require "active_support/core_ext/module/delegation"

module Cachext

  class << self
    delegate :fetch, :backup_key, to: :client
  end

  def self.client
    @client ||= Client.new config
  end

  def self.config
    @config ||= Configuration.new
  end

end
