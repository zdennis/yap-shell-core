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
  spec.description   = %q{The Lagniappe "Yap" shell description.}
  spec.homepage      = "https://github.com/zdennis/yap-shell"
  spec.license       = "MIT"

  spec.post_install_message = <<-POST_INSTALL_MESSAGE.gsub(/^\s*\|/, '')
    |
    |Greetings forward-thinking traveler!
    |
    |Let's waste no time and get right to it.
    |
    |\e[033mFirstly\e[0m, thank you for installing the yap shell!
    |
    |\e[033mSecondly\e[0m, this is my beta's beta. Yap has many cool ideas. I dare
    |say some of those made it into this very release.
    |
    |\e[033mLastly\e[0m, create an alias to the yap executable using the ruby version
    |you just installed it for. For example, with rbenv I use the below
    |alias in my ~/.profile file:
    |
    |    alias yap='rbenv local 2.2.3 && yap'
    |
    |If you are interested in tracing yap's execution you can add the DEBUG and TREEFELL_OUT options:
    |
    |    alias yap-debug='rbenv local 2.2.3 ; DEBUG=* TREEFELL_OUT=/tmp/yap-debug.log yap'
    |
    |Then, `source ~/.profile` or reload your shell. Now you can finally run:
    |
    |    yap
    |
    |You know your tooling better than me. If you need things to go a little
    |differently than above you go right ahead. If any questions arise don't
    |hesitate to holler over at Github. I may not always be home, but there will
    |always be a cozy textarea with dozens of emoji friends waiting to hear your
    |thoughts. All day. All night.
    |
    |Until the next update: Happy coding!
    |
    |Sincerely,
    |
    |     \e[51mThe Lagniappe (Yap) Shell\e[0m
    |
    |\e[033mP.S.\e[0m If you have ideas for loading other than the hard-coded
    |alias, do tell, right over here:
    |
    |     \e[1mhttp://github.com/zdennis/yap-shell/issues\e[0m
    |
    |\e[033mP.P.S.\e[0m OSX support? YES! Linux? I assume YES! Windows? Um...
    |
  POST_INSTALL_MESSAGE

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
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
