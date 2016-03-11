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

    def fetch key, options_hash = {}, &block
      options = Options.new @config, options_hash

      retval = read key, options
      return retval unless retval.nil?

      call_block key, options, &block

    rescue *Array(options.not_found_error) => e
      handle_not_found key, options, e
    rescue Features::Lock::TimeoutWaitingForLock, *options.errors => e
      handle_error key, options, e
    end

    private

    def call_block key, options, &block
      fresh = block.call

      write key, fresh, options

      fresh
    end

    def handle_not_found key, options, error
      raise if options.reraise_errors
    end

    def handle_error key, options, error
      @config.error_logger.call error if @config.log_errors?
      raise if @config.raise_errors && options.reraise_errors
    end

    def read key, options
      key.read
    end

    def write key, fresh, options
      key.write fresh, expires_in: options.expires_in
    end
  end
end
