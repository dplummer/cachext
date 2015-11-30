module Cachext
  class Configuration
    attr_accessor :raise_errors,
      :cache,
      :error_logger,
      :default_errors,
      :not_found_errors

    def initialize
      self.raise_errors = false
      self.default_errors = [
        Faraday::Error::ConnectionFailed,
        Faraday::Error::TimeoutError,
      ]
      self.not_found_errors = [
        Faraday::Error::ResourceNotFound,
      ]
    end
  end
end
