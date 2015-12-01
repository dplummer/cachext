module Cachext
  module Features
    module Lock
      TimeoutWaitingForLock = Class.new(StandardError)

      def call_block key, options, lock_info, &block
        with_heartbeat_extender key.digest, options.heartbeat_expires, lock_info do
          super
        end
      end

      def with_heartbeat_extender lock_key, heartbeat_expires, lock_info, &block
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
        @config.lock_manager.unlock lock_info
        done = true
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
end
