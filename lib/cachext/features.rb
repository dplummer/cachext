module Cachext
  module Features
    autoload :Backup, "cachext/features/backup"
    autoload :CircuitBreaker, "cachext/features/circuit_breaker"
    autoload :DebugLogging, "cachext/features/debug_logging"
    autoload :Default, "cachext/features/default"
    autoload :Lock, "cachext/features/lock"
  end
end
