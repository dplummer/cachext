$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "pry"

require "cachext"

require "active_support/core_ext/numeric/time"
require "active_support/cache"
require "logger"
require "stringio"
require "redis"
require "thread/pool"
require "timecop"

FooError = Class.new(StandardError)

class DummyErrorLogger
  def call(_)
  end
end

MEMCACHE = ActiveSupport::Cache::MemCacheStore.new
REDIS = Redis.new
LOGGER = DummyErrorLogger.new

RSpec.configure do |config|
  config.before do
    Cachext.configure do |c|
      c.cache = MEMCACHE
      c.redis = REDIS
      c.error_logger = LOGGER
    end
    Cachext.flush
  end

  config.after do
    Timecop.return
  end
end
