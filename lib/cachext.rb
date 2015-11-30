require "cachext/version"
require "faraday/error"

module Cachext
  DEFAULT_ERRORS = [
    Faraday::Error::ConnectionFailed,
    Faraday::Error::TimeoutError,
  ]
  NOT_FOUND_ERRORS = [
    Faraday::Error::ResourceNotFound,
  ]

  class << self
    attr_accessor :raise_errors, :cache, :error_logger
  end
  self.raise_errors = false

  def self.fetch key, expires_in:, default: nil, errors: DEFAULT_ERRORS, reraise_errors: true, not_found_error: NOT_FOUND_ERRORS
    cache.fetch key, expires_in: expires_in do
      fresh = yield
      write_backup key, fresh
      fresh
    end
  rescue *Array(not_found_error)
    delete_backup key
    raise if reraise_errors
    default.respond_to?(:call) ? default.call(key) : default
  rescue *errors => e
    error_logger.error e
    raise if raise_errors && reraise_errors
    read_backup(key) || (default.respond_to?(:call) ? default.call(key) : default)
  end

  def self.delete_backup key
    cache.delete backup_key(key)
  end

  def self.write_backup key, object
    cache.write backup_key(key), object
  end

  def self.read_backup key
    cache.read backup_key(key)
  end

  def self.read_multi_backup *keys
    cache.read_multi(*keys.map { |key| backup_key key })
  end

  def self.backup_key key
    [:backup_cache] + Array(key)
  end
end
