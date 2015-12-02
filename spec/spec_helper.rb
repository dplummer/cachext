$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "pry"

require "cachext"

require "active_support/core_ext/numeric/time"
require "active_support/cache"
require "logger"
require "stringio"
require "redis"
require "thread/pool"

class DummyErrorLogger
  def call(_)
  end
end

MEMCACHE = ActiveSupport::Cache::MemCacheStore.new
REDIS = Redis.new
LOGGER = DummyErrorLogger.new

RSpec.configure do |config|
  config.before do
    Cachext.config.cache = MEMCACHE
    Cachext.config.redis = REDIS
    Cachext.config.error_logger = LOGGER
  end
end

