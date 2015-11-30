module Cachext
  class Client
    def initialize(config)
      @config = config
    end

    def fetch key, expires_in:, default: nil, errors: @config.default_errors, reraise_errors: true, not_found_error: @config.not_found_errors
      @config.cache.fetch key, expires_in: expires_in do
        fresh = yield
        write_backup key, fresh
        fresh
      end
    rescue *Array(not_found_error)
      delete_backup key
      raise if reraise_errors
      default.respond_to?(:call) ? default.call(key) : default
    rescue *errors => e
      @config.error_logger.error e
      raise if @config.raise_errors && reraise_errors
      read_backup(key) || (default.respond_to?(:call) ? default.call(key) : default)
    end

    def backup_key key
      [:backup_cache] + Array(key)
    end

    private

    def delete_backup key
      @config.cache.delete backup_key(key)
    end

    def write_backup key, object
      @config.cache.write backup_key(key), object
    end

    def read_backup key
      @config.cache.read backup_key(key)
    end

    def read_multi_backup *keys
      @config.cache.read_multi(*keys.map { |key| backup_key key })
    end
  end
end
