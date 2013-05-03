# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'unmangler/version'

Gem::Specification.new do |gem|
  gem.name          = "unmangler"
  gem.version       = Unmangler::VERSION
  gem.authors       = ["Andrey \"Zed\" Zaikin"]
  gem.email         = ["zed.0xff@gmail.com"]
  gem.description   = %q{Unmangles mangled C++/Delphi names"}
  gem.summary       = gem.description + %q{, i.e. '@myclass@func$qil' => 'myclass::func(int, long)'}
  gem.homepage      = "http://zed.0xff.me"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
