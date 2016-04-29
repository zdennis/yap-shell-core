require 'yap/configuration'
require 'yap/shell'
require 'yap/world'

module Yap
  def self.run_shell
    addons = [
      World::Addons.load_directories(configuration.addon_paths),
      World::Addons.load_rcfiles(configuration.rcfiles)
    ].flatten

    Shell::Impl.new(addons: addons).repl
  end
end
