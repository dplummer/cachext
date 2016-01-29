module Cachext
  module Features
    module DebugLogging

      private

      def read key, options
        retval = super
        debug_log { { m: :read, key: key, retval: retval } }
        retval
      end

      def handle_not_found key, options, error
        debug_log { { m: :handle_not_found, key: key, error: error, reraise_errors: options.reraise_errors } }
        super
      end

      def handle_error key, options, error
        debug_log { { m: :handle_error, key: key, error: error } }
        super
      end

      def obtain_lock key, options
        lock_info = super
        debug_log { { m: :obtain_lock, key: key }.merge(lock_info) }
        lock_info
      end

      def wait_for_lock key, start_time
        debug_log { { m: :wait_for_lock, key: key, waited: (Time.now - start_time) } }
        super
      end

      def write key, fresh, options
        super
        debug_log { { m: :write, key: key, fresh: fresh, expires_in: options.expires_in, read: key.read } }
      end

      def debug_log
        @config.debug do
          log = yield
          msg = log.is_a?(String) ? log : log.inspect
          $stderr.puts "[#{Time.now.to_s(:db)}] [#{Process.pid} #{Thread.current.object_id.to_s(16)}] #{msg}"
        end
      end
    end
  end
end
