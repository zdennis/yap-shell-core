# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'yap/shell/version'

Gem::Specification.new do |spec|
  spec.name          = "yap-shell-core"
  spec.version       = Yap::Shell::VERSION
  spec.authors       = ["Zach Dennis"]
  spec.email         = ["zach.dennis@gmail.com"]
  spec.summary       = %q{The core of yap-shell.}
  spec.description   = %q{The core of yap-shell.}
  spec.homepage      = "https://github.com/zdennis/yap-shell-core"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = []
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  # Be specific about these dependencies otherwise RubyGems may print
  # following warning:
  #
  #    WARN: Unresolved specs during Gem::Specification.reset
  #
  # This warning is caused by RubyGems having multiple versions of a gem
  # installed that could match requirements.
  spec.add_dependency "tins", "~> 1.10.2"
  spec.add_dependency "coderay", "~> 1.1.1"
  spec.add_dependency "treefell", "~> 0.3.1"

  # Normal dependencies
  spec.add_dependency "pry-byebug", "~> 3.4.0"
  spec.add_dependency "yap-shell-parser", "~> 0.7.2"
  spec.add_dependency "term-ansicolor", "~> 1.3"
  spec.add_dependency "ruby-termios", "~> 0.9.6"
  spec.add_dependency "ruby-terminfo", "~> 0.1.1"
  spec.add_dependency "yap-rawline", "~> 0.7.0"
  spec.add_dependency "chronic", "~> 0.10.2"

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake", "~> 11"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "childprocess", "~> 0.5.9"
end
