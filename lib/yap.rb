require 'yap/shell'
require 'yap/world'

module Yap
  def self.run_shell
    addons = []
    addons.push World::Addons.load_directories Dir["#{ENV['HOME']}/.yap-addons/*"]
    addons.push World::Addons.load_rcfiles Dir["#{ENV['HOME']}/.yaprc"]

    Shell::Impl.new(addons: addons.flatten).repl
  end
end
