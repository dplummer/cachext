module Cachext
  module Features
    module CircuitBreaker
      attr_reader :breaker

      def initialize config
        super
        @breaker = Breaker.new(config)
      end

      def read key, options
        circuit = breaker.for(key)
        if circuit.open?
          val = key.read_backup
          debug_log { { m: :circuit_open, key: key, msg: "Circuit breaker open, reading from backup", val: val.inspect } }
          val
        else
          circuit.check_health
          super
        end
      end

      def handle_error key, options, error
        breaker.for(key).increment_failure
        super
      end
    end
  end
end
