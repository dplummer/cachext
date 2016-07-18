require "thread"

module Cachext
  class Breaker
    attr_reader :config

    def initialize(config)
      @config = config
    end

    def for(key)
      WithKey.new(config, key)
    end

    class WithKey
      attr_reader :config, :key

      def initialize(config, key)
        @config = config
        @key = key
      end

      def increment_failure
        redis.pipelined do
          redis.set key_str(:last_failure), Time.now.to_f
          redis.incr key_str(:monitor)
        end
      end

      def check_health
        if half_open?
          if health_check >= config.failure_threshold
            reset!
          else
            increment_health_check
          end
        end
      end

      def reset!
        redis.del key_str(:monitor),
                  key_str(:health_check),
                  key_str(:last_failure)
      end

      def open?
        state == :open
      end

      def half_open?
        state == :half_open
      end

      def state
        if (lf = last_failure) && (lf + config.breaker_timeout < Time.now.to_f)
          :half_open
        elsif monitor >= config.failure_threshold
          :open
        else
          :close
        end
      end

      def monitor
        redis.get(key_str(:monitor)).to_i
      end

      def last_failure
        lf = redis.get key_str(:last_failure)
        lf.nil? ? nil : lf.to_f
      end

      def health_check
        redis.get(key_str(:health_check)).to_i
      end

      def increment_health_check
        redis.incr key_str(:health_check)
      end

      def key_str(name)
        "#{name}:#{key.raw.map(&:to_s).join(":")}"
      end

      def redis
        config.lock_redis
      end
    end
  end
end
