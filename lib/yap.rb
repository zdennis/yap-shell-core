require 'yap/shell'
require 'yap/world'

module Yap
  def self.run_shell
    addons = []
    addons.push World::Addons.load_addons_from_files(dir:"#{ENV['HOME']}", files:Dir["#{ENV['HOME']}/.yaprc"])
    addons.push World::Addons.load_addons_from_files(dir:"#{ENV['HOME']}/.yap-addons/", files:Dir["#{ENV['HOME']}/.yap-addons/**/*.rb"])

    Shell::Impl.new(addons: addons.flatten).repl
  end
end
