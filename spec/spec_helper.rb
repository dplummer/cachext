$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "pry"

require "cachext"
require "active_support/core_ext/numeric/time"
require "active_support/cache"
require "logger"
require "stringio"

class DummyErrorLogger
  def error(_)
  end
end

Cachext.config.cache = ActiveSupport::Cache::MemoryStore.new
Cachext.config.error_logger = DummyErrorLogger.new
