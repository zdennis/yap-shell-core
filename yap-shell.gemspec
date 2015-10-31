# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'yap/shell/version'

Gem::Specification.new do |spec|
  spec.name          = "yap-shell"
  spec.version       = Yap::Shell::VERSION
  spec.authors       = ["Zach Dennis"]
  spec.email         = ["zach.dennis@gmail.com"]
  spec.summary       = %q{The Lagniappe "Yap" shell.}
  spec.description   = %q{The Lagniappe "Yap" shell.}
  spec.homepage      = "https://github.com/zdennis/yap-shell"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  # spec.add_dependency "yap-shell-parser", "~> 0.1.0"
  spec.add_dependency "term-ansicolor", "~> 1.3"
  spec.add_dependency "ruby-termios", "~> 0.9.6"
  spec.add_dependency "ruby-terminfo"
  spec.add_dependency "activesupport", "~> 4.2.4"

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake", "~> 10"

  #--BEGIN_ADDON_GEM_DEPENDENCIES--#
  spec.add_dependency "chronic", "~> 0.10.2"
  spec.add_dependency "term-ansicolor"
  #--END_ADDON_GEM_DEPENDENCIES--#
end
