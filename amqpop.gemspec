# -*- encoding: utf-8 -*-
require File.expand_path('../lib/amqpop/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Chris Cherry"]
  gem.email         = ["ctcherry@gmail.com"]
  gem.description   = %q{Command line AMQP consumer}
  gem.summary       = %q{Command line tool for consuming messages off of an AMQP queue and dispatching them to a user specified command}
  gem.homepage      = "https://github.com/ctcherry/amqpop"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^spec/})
  gem.name          = "amqpop"
  gem.require_paths = ["lib"]
  gem.version       = Amqpop::VERSION

  gem.add_dependency "amqp", "~> 0.9.8"
  gem.add_development_dependency "rspec", "~> 2.12.0"
end
