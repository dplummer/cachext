# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cachext/version'

Gem::Specification.new do |spec|
  spec.name          = "cachext"
  spec.version       = Cachext::VERSION
  spec.authors       = ["Donald Plummer"]
  spec.email         = ["donald.plummer@gmail.com"]

  spec.summary       = %q{Cache with lock and backup extensions}
  spec.description   = %q{Don't calculate the cached value twice at the same time. Use a backup of the data if the service is down.}
  spec.homepage      = "https://github.com/dplummer/cachext"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport"
  spec.add_dependency "redis"
  spec.add_dependency "redis-namespace"
  spec.add_dependency "redlock"
  spec.add_dependency "faraday"
  spec.add_dependency "dalli"

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "thread"
end
