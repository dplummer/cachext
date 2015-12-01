module Cachext
  class Key
    attr_reader :raw

    def initialize(raw, config: Cachext.config)
      @raw = Array(raw)
      @config = config
    end

    def inspect
      "#<Cachext::Key:#{object_id} @raw=#{@raw.inspect} digest=#{digest}>"
    end

    def digest
      ::Digest::SHA1.hexdigest ::Marshal.dump(raw)
    end

    def backup
      [:backup_cache] + raw
    end

    def locked?
      @config.lock_redis.exists digest
    end

    def read
      @config.cache.read raw
    end

    def write value, options = {}
      @config.cache.write raw, value, options
    end

    def clear
      @config.cache.delete raw
    end
  end
end
