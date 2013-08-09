# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rackstash/version'

Gem::Specification.new do |gem|
  gem.name          = "rackstash"
  gem.version       = Rackstash::VERSION
  gem.authors       = ["Holger Just, Planio GmbH"]
  gem.email         = ["holger@plan.io"]
  gem.description   = %q{Making Rack and Rails logs useful}
  gem.summary       = %q{Making Rack and Rails logs useful}
  gem.homepage      = "https://github.com/planio-gmbh/rackstash"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency "logstash-event"
  gem.add_runtime_dependency "activesupport"
  gem.add_runtime_dependency "thor"

  gem.add_development_dependency "minitest"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "json"
end
