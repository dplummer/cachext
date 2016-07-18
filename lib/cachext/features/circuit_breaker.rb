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
          key.read_backup
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
