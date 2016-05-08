require 'treefell'

module Yap
  require 'yap/configuration'
  require 'yap/shell'
  require 'yap/world'

  def self.run_shell
    Treefell['shell'].puts "#{self}.#{__callee__} booting shell"
    addons = [
      World::Addons.load_directories(configuration.addon_paths),
      World::Addons.load_rcfiles(configuration.rcfiles)
    ].flatten

    Shell::Impl.new(addons: addons).repl
  end
end
