module Cachext
  module Features
    module Default
      def handle_not_found key, options, error
        super
        options.default.respond_to?(:call) ? options.default.call(key) : options.default
      end

      def handle_error key, options, error
        super || (options.default.respond_to?(:call) ? options.default.call(key) : options.default)
      end
    end
  end
end
