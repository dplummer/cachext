require "digest/sha1"

module Cachext
  class Client
    prepend Features::DebugLogging
    prepend Features::Lock
    prepend Features::Backup
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
      if !retval.nil?
        @config.lock_manager.unlock lock_info
        return retval
      end

      call_block key, options, lock_info, &block

    rescue *Array(options.not_found_error) => e
      handle_not_found key, options, e
    rescue Features::Lock::TimeoutWaitingForLock, *options.errors => e
      handle_error key, options, e
    end

    private

    def call_block key, options, lock_info, &block
      fresh = block.call

      write key, fresh, options

      fresh
    end

    def handle_not_found key, options, error
      raise if options.reraise_errors
    end

    def handle_error key, options, error
      @config.error_logger.error error
      raise if @config.raise_errors && reraise_errors
    end

    def read key, _lock_info = {}
      key.read
    end

    def write key, fresh, options
      key.write fresh, expires_in: options.expires_in
    end
  end
end
