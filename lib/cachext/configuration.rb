require "redlock"
require "redis-namespace"

module Cachext
  class Configuration
    attr_accessor :raise_errors,       # raise all errors all the time? (for tests)
                  :default_expires_in, # in seconds
                  :cache,              # conform to ActiveSupport::Cache interface
                  :redis,              # redis client for locking
                  :error_logger,       # conform to Honeybadger interface
                  :default_errors,     # array of errors to catch and not reraise
                  :not_found_errors,   # array of errors where we delete the backup and reraise
                  :max_lock_wait,      # time in seconds to wait for a lock
                  :debug,              # output debug messages to STDERR
                  :heartbeat_expires   # time in seconds for process heardbeat to expire

    def initialize
      self.raise_errors = false
      self.default_errors = [
        Faraday::Error::ConnectionFailed,
        Faraday::Error::TimeoutError,
      ]
      self.not_found_errors = [
        Faraday::Error::ResourceNotFound,
      ]
      self.default_expires_in = 60
      self.max_lock_wait = 5
      self.debug = ENV['CACHEXT_DEBUG'] == "true"
      self.heartbeat_expires = 2
    end

    def lock_manager
      @lock_manager ||= Redlock::Client.new [lock_redis], retry_count: 1
    end

    def lock_redis
      @lock_redis ||= Redis::Namespace.new :cachext, redis: redis
    end
  end
end
