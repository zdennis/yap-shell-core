require "term/ansicolor"
require "tins"
require "byebug"
require "pry"
require "treefell"
require 'optparse'

module Yap
  require 'yap/cli/options'
  require 'yap/configuration'
  require 'yap/shell'
  require 'yap/world'

  def self.root
    Pathname.new File.join(File.dirname(__FILE__), '..')
  end

  def self.run_shell(argv)
    Treefell['shell'].puts "#{self}.#{__callee__} booting shell"

    yap_options = Yap::Cli::Options.new
    yap_options.parse(argv)

    if configuration.run_shell?
      addons_loaded = []
      if configuration.use_addons?
        Treefell['shell'].puts "#{self}.#{__callee__} loading addons"
        addons = Yap::Addon.load_for_configuration(configuration)
        addons_loaded.concat addons
      else
        Treefell['shell'].puts "#{self}.#{__callee__} skipping addons"
      end

      if configuration.use_rcfiles?
        Treefell['shell'].puts "#{self}.#{__callee__} loading rcfiles"
        addons_loaded.concat \
          Yap::Addon.load_rcfiles(configuration.rcfiles)
      else
        Treefell['shell'].puts "#{self}.#{__callee__} skipping rcfiles"
      end

      Shell::Impl.new(addons: addons_loaded).repl
    elsif yap_options.commands.any?
      yap_options.commands.last.process
    else
      STDERR.puts "Honestly, I don't know what you're tring to do."
      exit 1
    end
  end
end
