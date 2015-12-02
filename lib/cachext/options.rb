require "ostruct"
module Cachext
  class Options
    attr_reader :expires_in,
                :default,
                :errors,
                :reraise_errors,
                :not_found_error,
                :heartbeat_expires

    def initialize config,
                   expires_in: config.default_expires_in,
                   default: nil,
                   errors: config.default_errors,
                   reraise_errors: true,
                   not_found_error: config.not_found_errors,
                   heartbeat_expires: config.heartbeat_expires

      @expires_in = expires_in
      @default = default
      @errors = errors
      @reraise_errors = reraise_errors
      @not_found_error = not_found_error
      @heartbeat_expires = heartbeat_expires
    end
  end
end
