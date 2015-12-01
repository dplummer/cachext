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

      retval = key.read
      debug_log { { s: 1, key: key, retval: retval } }
      return retval unless retval.nil?

      start_time = Time.now

      until lock_info = @config.lock_manager.lock(key.digest, (heartbeat_expires * 1000).ceil)
        debug_log { { s: 2, key: key, msg: "Waiting for lock" } }
        sleep rand
        if Time.now - start_time > @config.max_lock_wait
          raise TimeoutWaitingForLock
        end
      end

      retval = key.read
      debug_log { { s: 3, key: key, retval: retval }.merge(lock_info) }
      return retval unless retval.nil?

      begin
        fresh = with_heartbeat_extender(key.digest, heartbeat_expires, lock_info, &block)

        key.write fresh, expires_in: expires_in
        debug_log { { s: 4, key: key, fresh: fresh, expires_in: expires_in, read: key.read } }
        write_backup key, fresh
        fresh
      ensure
        @config.lock_manager.unlock lock_info
      end

    rescue *Array(not_found_error) => e
      debug_log { { s: 5, key: key, error: e } }
      delete_backup key
      raise if reraise_errors
      default.respond_to?(:call) ? default.call(key) : default
    rescue TimeoutWaitingForLock, *errors => e
      debug_log { { s: 6, key: key, error: e } }
      @config.error_logger.error e
      raise if @config.raise_errors && reraise_errors
      read_backup(key) || (default.respond_to?(:call) ? default.call(key) : default)
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
          @config.lock_manager.lock lock_key, (heartbeat_expires * 1000).ceil, extend: lock_info
        end
      end

      block.call
    ensure
      done = true
    end

    def delete_backup key
      @config.cache.delete key.backup
    end

    def write_backup key, object
      @config.cache.write key.backup, object
    end

    def read_backup key
      @config.cache.read key.backup
    end

    def debug_log
      if @config.debug
        Thread.exclusive do
          log = yield
          msg = log.is_a?(String) ? log : log.inspect
          $stderr.puts "[#{Time.now.to_s(:db)}] [#{Process.pid} #{Thread.current.object_id.to_s(16)}] #{msg}"
        end
      end
    end
  end
end
