require "digest/sha1"

module Cachext
  class Client
    TimeoutWaitingForLock = Class.new(StandardError)

    prepend Features::DebugLogging
    prepend Features::Default

    def initialize config
      @config = config
    end

    def fetch key, options_hash, &block
      options = Options.new @config, options_hash

      retval = read key
      return retval unless retval.nil?

      lock_info = obtain_lock key, options

      retval = read key, lock_info
      return retval unless retval.nil?

      begin
        fresh = with_heartbeat_extender(key.digest, options.heartbeat_expires, lock_info, &block)

        write key, fresh, options

        fresh
      ensure
        @config.lock_manager.unlock lock_info
      end

    rescue *Array(options.not_found_error) => e
      handle_not_found key, options, e
    rescue TimeoutWaitingForLock, *options.errors => e
      handle_error key, options, e
    end

    private

    def handle_not_found key, options, error
      key.delete_backup
      raise if options.reraise_errors
    end

    def handle_error key, options, error
      @config.error_logger.error error
      raise if @config.raise_errors && reraise_errors
      key.read_backup
    end

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

    def read key, _lock_info = {}
      key.read
    end

    def write key, fresh, options
      key.write fresh, expires_in: options.expires_in
      key.write_backup fresh
    end

    def obtain_lock key, options
      start_time = Time.now

      until lock_info = @config.lock_manager.lock(key.digest, (options.heartbeat_expires * 1000).ceil)
        wait_for_lock key, start_time
      end

      lock_info
    end

    def wait_for_lock key, start_time
      sleep rand
      if Time.now - start_time > @config.max_lock_wait
        raise TimeoutWaitingForLock
      end
    end
  end
end
