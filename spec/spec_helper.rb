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

RSpec.configure do |config|
  config.before do
    Cachext.configure do |c|
      c.cache = ActiveSupport::Cache::MemCacheStore.new
      c.redis = Redis.new
      c.error_logger = DummyErrorLogger.new
    end
    Cachext.flush
  end

  config.after do
    Timecop.return
  end
end
