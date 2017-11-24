module Cachext
  class Key
    attr_reader :raw

    def initialize(raw, config: Cachext.config)
      @raw = Array(raw)
      @config = config
    end

    def inspect
      "#<Cachext::Key:#{object_id.to_s(16)} @raw=#{@raw.inspect} digest=#{digest}>"
    end

    def digest
      ::Digest::SHA1.hexdigest ::Marshal.dump(raw)
    end

    def backup
      [:backup_cache] + raw
    end

    def lock_key
      "cachext:lock:#{digest}"
    end

    def locked?
      lock_redis.exists lock_key
    end

    def read
      cache.read raw
    end

    def write value, options = {}
      cache.write raw, value, options
    end

    def clear
      cache.delete raw
    end

    def read_backup
      cache.read backup
    end

    def write_backup value
      cache.write backup, value
    end

    def delete_backup
      cache.delete backup
    end

    private

    def cache
      @config.cache
    end

    def lock_redis
      @config.lock_redis
    end
  end
end
