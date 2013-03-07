# -*- encoding: utf-8 -*-
require File.expand_path('../lib/multisert/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Jeff Iacono"]
  gem.email         = ["jeff.iacono@gmail.com"]
  gem.description   = %q{Buffer to handle bulk INSERTs}
  gem.summary       = %q{Buffer to handle bulk INSERTs}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "multisert"
  gem.require_paths = ["lib"]
  gem.version       = Multisert::VERSION

  gem.add_development_dependency "mysql2"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "cane"
  gem.add_development_dependency "rspec", [">= 2"]
end
