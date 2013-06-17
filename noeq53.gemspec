# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.authors       = ["Jonathan Rudenberg", "Burke Libbey"]
  gem.email         = ["jonathan@titanous.com", "burke@libbey.me"]
  gem.description   = %q{Ruby noeq53 GUID client}
  gem.summary       = %q{Ruby noeq53 GUID client}
  gem.homepage      = "http://github.com/shopify/noeq53-rb"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "noeq53"
  gem.require_paths = ["lib"]
  gem.version       = "0.2.0"
  gem.add_development_dependency('mocha')
end
