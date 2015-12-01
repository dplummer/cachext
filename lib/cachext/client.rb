require "digest/sha1"

module Cachext
  class Client
    TimeoutWaitingForLock = Class.new(StandardError)

    prepend Features::Default

    def initialize(config)
      @config = config
    end

    def fetch key, options_hash, &block
      options = Options.new @config, options_hash

      retval = key.read
      debug_log { { s: 1, key: key, retval: retval } }
      return retval unless retval.nil?

      start_time = Time.now

      until lock_info = @config.lock_manager.lock(key.digest, (options.heartbeat_expires * 1000).ceil)
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
        fresh = with_heartbeat_extender(key.digest, options.heartbeat_expires, lock_info, &block)

        key.write fresh, expires_in: options.expires_in
        debug_log { { s: 4, key: key, fresh: fresh, expires_in: options.expires_in, read: key.read } }
        key.write_backup fresh
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
      debug_log { { m: :handle_not_found, key: key, error: error, reraise_errors: options.reraise_errors } }
      key.delete_backup
      raise if options.reraise_errors
    end

    def handle_error key, options, error
      debug_log { { m: :handle_error, key: key, error: error } }
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
