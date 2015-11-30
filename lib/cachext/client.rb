require "digest/sha1"

module Cachext
  class Client
    TimeoutWaitingForLock = Class.new(StandardError)

    def initialize(config)
      @config = config
    end

    def fetch key, expires_in: @config.default_expires_in,
                   default: nil,
                   errors: @config.default_errors,
                   reraise_errors: true,
                   not_found_error: @config.not_found_errors,
                   heartbeat_expires: 2,
                   &block

      retval = @config.cache.read key
      return retval unless retval.nil?

      start_time = Time.now

      until lock_info = @config.lock_manager.lock(digest(key), heartbeat_expires * 1000)
        sleep rand
        if Time.now - start_time > @config.max_lock_wait
          raise TimeoutWaitingForLock
        end
      end

      begin
        fresh = with_heartbeat_extender(digest(key), heartbeat_expires, lock_info, &block)

        @config.cache.write key, fresh, expires_in: expires_in
        write_backup key, fresh
        fresh
      ensure
        @config.lock_manager.unlock lock_info
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

    def clear key
      @config.cache.delete key
    end

    def locked? key
      @config.lock_redis.exists digest(key)
    end

    private

    def with_heartbeat_extender(lock_key, heartbeat_expires, lock_info, &block)
      done = false
      heartbeat_frequency = heartbeat_expires / 2

      Thread.new do
        loop do
          break if done
          sleep heartbeat_frequency
          break if done
          @config.lock_manager.lock lock_key, heartbeat_expires * 1000, extend: lock_info
        end
      end

      block.call
    ensure
      done = true
    end

    def digest key
      ::Digest::SHA1.hexdigest ::Marshal.dump(key)
    end

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
